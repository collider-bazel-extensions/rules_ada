# Bazel Ada Rules

[Bazel](https://bazel.build) rules for the [Ada](https://www.adaic.org/)
programming language.

## What's different about these rules

Earlier attempts at Ada-on-Bazel have generally been thin wrappers around
`gprbuild` or `gnatmake`, delegating the build graph to GNAT's own project
machinery. That works as a smoke test but loses the things you actually
adopt Bazel for: per-action caching, parallelism the build planner can
reason about, and remote execution.

`rules_ada` takes the harder path. It drives the GNAT front-end one Ada
unit at a time, treats each `.ali` and `.o` as a first-class Bazel output,
and lets toolchain resolution own toolchain selection. Concretely:

- **Per-unit actions, not project-file orchestration.** Every unit is a
  Bazel action; the binder and the link are also discrete actions.
- **Spec/body split for cross-library incrementality.** Specs compile to
  `-gnatc` interface ALIs that downstream consumes; bodies compile to
  full ALIs + objects for the binder and link. A change to a body does
  not invalidate downstream library compiles.
- **Hermetic FSF GNAT toolchain by default**, fetched from
  `alire-project/GNAT-FSF-builds` with sha-pinned tarballs. Five
  platforms wired (`linux x86_64/aarch64`, `darwin x86_64/aarch64`,
  `windows x86_64`).
- **System-GNAT escape hatch** for environments that can't fetch the
  tarball; opts back into host PATH via `use_host_env = True`.
- **`ada_shared_library` and `ada_static_library`** that expose `CcInfo`
  so `cc_binary` / `cc_library` can depend on Ada code directly, with
  `gnatbind` running in library mode (`-n -a -L<name>`) so elaboration
  fires automatically on `.so` load.
- **Subunit detection by convention with explicit override.** A
  hyphenated `.adb` without a matching `.ads` is treated as a `separate`
  subunit; the `subunits` attribute lets you override the heuristic for
  codebases using `Source_File_Name` pragmas.
- **AUnit integration** via a small repo-rule that fetches the upstream
  source-only tarball and exposes it as `@aunit//:aunit`.

The approach is validated against real upstream Ada code:
[`ada-toml`](https://github.com/pmderodat/ada-toml) parses TOML through
the rules end-to-end, and
[`AdaSAT`](https://github.com/AdaCore/AdaSAT)'s sudoku solver
(compiled with `copts = ["-gnat2022"]`) solves real puzzles.

## Installation

`MODULE.bazel`:

```starlark
bazel_dep(name = "rules_ada", version = "0.1.0")

fsf_gnat = use_extension("@rules_ada//toolchains/fsf_gnat:extensions.bzl", "fsf_gnat")
use_repo(fsf_gnat, "fsf_gnat")
register_toolchains("@fsf_gnat//:toolchain")
```

For AUnit-based testing, also wire:

```starlark
aunit = use_extension("@rules_ada//toolchains/aunit:extensions.bzl", "aunit")
use_repo(aunit, "aunit")
```

## Example

```starlark
load("@rules_ada//ada:defs.bzl", "ada_binary", "ada_library")

ada_library(
    name = "greet",
    srcs = ["greet.ads", "greet.adb"],
)

ada_binary(
    name = "hello",
    srcs = ["main.adb"],
    deps = [":greet"],
)
```

`bazel run //:hello`. The toolchain is fetched on first use.

## Documentation

| Doc                          | What it covers                                     |
| ---------------------------- | -------------------------------------------------- |
| [`docs/rules.md`](docs/rules.md) | Rule reference: attributes, providers, toolchain. |
| [`CHANGELOG.md`](CHANGELOG.md)   | Release notes.                                     |
| [`bcr/README.md`](bcr/README.md) | Bazel Central Registry submission instructions.    |
| `examples/hello/`            | Library + binary + tests + AUnit-based tests.      |
| `examples/cc_interop/`       | C consumer linking against Ada via `CcInfo`.       |

## Project status

Pre-1.0. The rule surface (`ada_library`, `ada_binary`, `ada_test`,
`ada_shared_library`, `ada_static_library`) is in place and covered by
analysis tests + real-codebase smoke tests. Genuinely outstanding before
a 1.0 tag:

- A real BCR submission (the `bcr/` package is ready to copy in once a
  release tarball exists).
- CI verification on macOS and Windows. The pre-pinned tarballs exist
  for those platforms but only `ubuntu-latest` runs in CI today.
- `ada_library` consuming a `cc_library` dep — Ada importing C is the
  one direction of interop not yet implemented. Larger codebases like
  `gnatcoll-core` are gated on this.

## Contributing

Contributions are welcome. We're particularly interested in:

- Real-codebase ports that surface bugs the synthetic examples miss.
- Additional platforms in the `fsf_gnat` `_PLATFORMS` table.
- Ada↔C interop in the Ada-imports-C direction.

**All contributed code must come with test coverage.** In this repo
that means:

- Starlark logic in `ada/`, `ada/private/`, or `toolchains/` needs an
  `analysistest` (or `unittest` for pure functions) under
  `tests/analysis/` or `tests/unit_naming/`. Action argv assertions and
  input-set assertions are the standard pattern — see
  `tests/analysis/incrementality/` for examples that lock invariants in
  place.
- New rule attributes need at least one test that exercises them.
- Bug fixes need a regression test that fails before the fix.
- Toolchain changes get validated under both `fsf_gnat` and
  `system_gnat` via `tools/test_matrix.sh`.

The full suite is `bazel test //...` (or `tools/test_matrix.sh` to run
under both toolchains). All 37 existing tests pass under both
configurations and CI requires the same.

## License

[Apache License 2.0](LICENSE).
