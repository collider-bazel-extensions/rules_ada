# Bazel Central Registry submission

Templates for submitting `rules_ada` to
[bazelbuild/bazel-central-registry](https://github.com/bazelbuild/bazel-central-registry).

## Per-release checklist

1. Tag the release: `git tag v0.1.0 && git push origin v0.1.0`.
2. GitHub creates the source tarball at:
   ```
   https://github.com/collider-bazel-extensions/rules_ada/archive/refs/tags/v0.1.0.tar.gz
   ```
3. Compute its sha256 and convert to the integrity format BCR uses:
   ```sh
   curl -fsSL https://github.com/collider-bazel-extensions/rules_ada/archive/refs/tags/v0.1.0.tar.gz \
     | sha256sum | cut -d' ' -f1 | xxd -r -p | base64 | sed 's/^/sha256-/'
   ```
4. Fork bazelbuild/bazel-central-registry. Copy the contents of `bcr/`
   into `modules/rules_ada/0.1.0/` (creating it if needed):
   - `source.json` — paste the integrity, set the URL.
   - `presubmit.yml` — adjust if needed (the default tests `//...`
     under all four BCR platforms).
   - `MODULE.bazel` — copy from this repo's root.
5. Update `modules/rules_ada/metadata.json` to include `"0.1.0"` in
   `versions`.
6. Open a PR against bazel-central-registry; BCR's automated checks will
   run the presubmit and report.
