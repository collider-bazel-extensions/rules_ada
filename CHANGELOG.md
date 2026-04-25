# Changelog

## 0.1.0 — initial public release

First versioned release. Pre-1.0 — public-API breadth and real-codebase
breadth still expanding (see `README.md` for the gap list).

### Rules

- `ada_library` — group of `.ads`/`.adb` files compiled into ALIs and
  objects. Spec/body split (`-gnatc` interface ALI for downstream compile
  inputs; full ALI + object for binder/link) for cross-library
  incrementality. Subunit detection via filename heuristic with explicit
  `subunits` attribute as escape hatch.
- `ada_binary` — single-main `.adb` → bind → link → executable.
- `ada_test` — `ada_binary` shape + Bazel test contract.
- `ada_shared_library` — PIC compile, library-mode binder
  (`gnatbind -n -a -L<name>`), `.so` output with libgnat statically
  embedded, `CcInfo` provider so `cc_binary`/`cc_library` can depend.
- `ada_static_library` — same compile + bind shape; `ar rcs` produces
  a PIC `.a` archive, exposed via `CcInfo` as `pic_static_library`.

### Attribute surface

- `copts` — additional gcc flags per target.
- `config_pragmas` — `.adc` file passed via `gcc -gnatec=`.
- `exports_bodies` (ada_library) — flow body sources to downstream
  compiles for cross-library generic instantiation.
- `subunits` (ada_library) — explicit list overriding the hyphen-stem
  heuristic.
- `data` — runfiles for `ada_binary`/`ada_test`.

### Toolchains

- `fsf_gnat` (default, hermetic) — pinned tarball from
  `alire-project/GNAT-FSF-builds`. Five platforms wired:
  linux x86_64/aarch64, darwin x86_64/aarch64, windows x86_64.
- `system_gnat` (escape hatch) — probes host GNAT via `gnatls -v`,
  symlinks runtime + binaries into the repo. `use_host_env = True`.
- `aunit` — fetches AUnit v25.0.0 source-only tarball, exposes as
  `@aunit//:aunit` ada_library.

### Tests

- 31 rule-level tests (5 unit_naming + 11 ada_library + 4 ada_binary +
  5 incrementality + 5 ada_shared_library + 1 example coverage gap)
  plus 2 example tests.
- Cross-toolchain matrix script `tools/test_matrix.sh` runs the full
  suite under both fsf_gnat and system_gnat.
- Real-codebase smoke tests: ada-toml v0.5 (TOML parser) and AdaSAT
  v25.0.0 (SAT solver). Both build through rules_ada and run end-to-end:
  ada-toml's decoder parses real TOML; AdaSAT's sudoku solver compiles
  with `-gnat2022 copts` and solves real puzzles.
- GitHub Actions CI runs the matrix on `ubuntu-latest`.
