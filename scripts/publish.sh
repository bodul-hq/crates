#!/usr/bin/env bash
# Publish a crate to the bodul registry.
#
#   scripts/publish.sh [--dry-run] <path-to-crate>
#
# Packages the crate with `cargo package` (which builds and verifies it), copies
# the resulting .crate file into this repository's `crates/` directory, commits,
# and pushes to `main`. The registry.yml workflow then redeploys the registry.
# It also tags the source repository with `v<version>` and pushes the tag.
#
# Refuses to run if either repository is dirty, the crate repo is not in sync
# with its upstream, this repo is not on `main`, or the version already exists.
#
# --dry-run does all checks and packaging but makes no commits, tags or pushes.
set -euo pipefail

die() { echo "error: $*" >&2; exit 1; }
info() { echo "==> $*"; }

DRY_RUN=0
if [[ "${1:-}" == "--dry-run" ]]; then DRY_RUN=1; shift; fi
[[ $# -eq 1 ]] || die "usage: $0 [--dry-run] <path-to-crate>"

REGISTRY_REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CRATE_DIR="$(cd "$1" && pwd)"
[[ -f "$CRATE_DIR/Cargo.toml" ]] || die "no Cargo.toml in $CRATE_DIR"

# --- Crate metadata --------------------------------------------------------
meta="$(cargo metadata --no-deps --format-version 1 --manifest-path "$CRATE_DIR/Cargo.toml")"
read -r NAME VERSION < <(python3 -c '
import json, sys, os
m = json.load(sys.stdin)
path = os.path.realpath(sys.argv[1])
p = next(p for p in m["packages"] if os.path.realpath(p["manifest_path"]) == path)
print(p["name"], p["version"])
' "$CRATE_DIR/Cargo.toml" <<<"$meta")
CRATE_FILE="$NAME-$VERSION.crate"
TAG="v$VERSION"
info "Publishing $NAME $VERSION from $CRATE_DIR"

# --- Pre-flight checks -------------------------------------------------------
[[ -e "$REGISTRY_REPO/crates/$CRATE_FILE" ]] \
  && die "$CRATE_FILE is already in the registry; bump the version in Cargo.toml"

check_repo() { # <dir> <label>
  local dir="$1" label="$2"
  [[ -z "$(git -C "$dir" status --porcelain)" ]] || die "$label has uncommitted changes"
  git -C "$dir" fetch --quiet --tags
  local upstream
  upstream="$(git -C "$dir" rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null)" \
    || die "$label: current branch has no upstream"
  [[ "$(git -C "$dir" rev-parse HEAD)" == "$(git -C "$dir" rev-parse "$upstream")" ]] \
    || die "$label is not in sync with $upstream (pull/push first)"
}

[[ "$(git -C "$REGISTRY_REPO" branch --show-current)" == "main" ]] \
  || die "registry repo ($REGISTRY_REPO) must be on main"
check_repo "$REGISTRY_REPO" "registry repo"
check_repo "$CRATE_DIR" "crate repo"

git -C "$CRATE_DIR" rev-parse -q --verify "refs/tags/$TAG" >/dev/null \
  && die "tag $TAG already exists in crate repo; bump the version in Cargo.toml"

# --- Package -----------------------------------------------------------------
info "cargo package"
(cd "$CRATE_DIR" && cargo package)
TARGET_DIR="$(python3 -c 'import json,sys; print(json.load(sys.stdin)["target_directory"])' <<<"$meta")"
PACKAGED="$TARGET_DIR/package/$CRATE_FILE"
[[ -f "$PACKAGED" ]] || die "expected $PACKAGED after cargo package"

if (( DRY_RUN )); then
  info "Dry run OK: would add crates/$CRATE_FILE, push registry main, tag and push $TAG"
  exit 0
fi

# --- Publish -----------------------------------------------------------------
info "Adding crates/$CRATE_FILE to registry"
cp "$PACKAGED" "$REGISTRY_REPO/crates/$CRATE_FILE"
git -C "$REGISTRY_REPO" add "crates/$CRATE_FILE"
git -C "$REGISTRY_REPO" commit --quiet -m "Publish $NAME $VERSION"
git -C "$REGISTRY_REPO" push --quiet

info "Tagging $TAG in crate repo"
git -C "$CRATE_DIR" tag -a "$TAG" -m "$NAME $VERSION"
git -C "$CRATE_DIR" push --quiet origin "$TAG"

info "Done. $NAME $VERSION will be live once the registry workflow finishes."
