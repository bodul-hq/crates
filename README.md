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

1. Package the crate. Its dependencies on other registry crates must specify
   `registry = "bodul"` so the packaged manifest points back here:

   ```sh
   cargo package
   ```

2. Copy the resulting `target/package/<name>-<version>.crate` into `crates/`
   in this repository, commit it, and push to `main`.

The [`registry.yml`](.github/workflows/registry.yml) workflow rebuilds the
whole registry from `crates/` and deploys it to GitHub Pages. To unpublish a
version, delete its `.crate` file and push. Versions are immutable once
people depend on them, so prefer publishing a new version over replacing one.
