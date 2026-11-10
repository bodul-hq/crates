# bodul crate registry

A static Cargo registry built with [margo](https://github.com/integer32llc/margo)
and hosted on GitHub Pages at <https://bodul-hq.github.io/crates/>.

## Using crates from this registry

Add the registry to `.cargo/config.toml` in your project (or `~/.cargo/config.toml`):

```toml
[registries]
bodul = { index = "sparse+https://bodul-hq.github.io/crates/" }
```

Then depend on a crate:

```sh
cargo add --registry bodul some-crate
```

## Publishing a crate

Use the publish script, with this repo checked out on `main`:

```sh
scripts/publish.sh --dry-run ../lib_everyday   # checks + cargo package only
scripts/publish.sh ../lib_everyday
```

It checks that both repos are clean and in sync with upstream and that the
version is new. Then it runs `cargo package`, copies
`<name>-<version>.crate` into `crates/`, commits, and pushes to `main`.
Finally it tags the source repo with `v<version>`. Crates set
`publish = ["bodul"]` in `Cargo.toml` so they never go to crates.io by mistake.
Dependencies on other registry crates must specify `registry = "bodul"`.

The [`registry.yml`](.github/workflows/registry.yml) workflow rebuilds the
whole registry from `crates/` and deploys it to GitHub Pages. To unpublish a
version, delete its `.crate` file and push. Versions are immutable once
people depend on them, so prefer publishing a new version over replacing one.
