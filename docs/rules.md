# rules_ada — rule reference

Public symbols are loaded from `@rules_ada//ada:defs.bzl`:

```starlark
load("@rules_ada//ada:defs.bzl", "ada_binary", "ada_library", "ada_test")
```

## `ada_library`

A set of `.ads`/`.adb` files compiled into a closure of ALIs and objects.
Provides `AdaInfo` for downstream `ada_*` targets.

| Attribute        | Type            | Default | Description |
|------------------|-----------------|---------|-------------|
| `srcs`           | `label_list`    | required| `.ads`/`.adb` source files. Subunits (`separate` bodies) are detected by convention — a `.adb` whose stem contains `-` and which has no matching `.ads` is treated as a subunit. |
| `deps`           | `label_list`    | `[]`    | Other `ada_library` targets. Their `transitive_spec_alis` and `transitive_specs` flow into this target's compile inputs. |
| `copts`          | `string_list`   | `[]`    | Compiler flags appended to every `gcc` compile for this target's units, after the rule's own structural flags. |
| `config_pragmas` | `label`         | `None`  | Optional `.adc` file passed via `gcc -gnatec=` to every compile. |
| `exports_bodies` | `bool`          | `False` | If `True`, this library's body sources flow into downstream compile inputs. Set this on libraries whose public API exposes generics — cross-unit instantiation needs the generic body at the instantiation site's compile time. Costs incrementality on downstream consumers; only turn on when needed. |

**Action graph per unit:**
- Body-having units → one `AdaCompileInterface` (`-gnatc`, emits `.ali` only) plus one `AdaCompileFull` (emits `.ali` + `.o`).
- Spec-only units → one `AdaCompileFull` on the spec.
- Subunits → no standalone action; flow as input to their parent's compile.

## `ada_binary`

Single-main `.adb` → bind → link → executable.

| Attribute        | Type            | Default | Description |
|------------------|-----------------|---------|-------------|
| `srcs`           | `label_list`    | required| Exactly one main unit. `srcs` may include the main spec + body or just the body for a body-only main procedure. Subunits are not allowed at the binary level — keep them in an `ada_library`. |
| `deps`           | `label_list`    | `[]`    | `ada_library` deps. |
| `data`           | `label_list`    | `[]`    | Runtime data files made available via runfiles. |
| `copts`          | `string_list`   | `[]`    | Compiler flags for the main and binder body compiles. |
| `config_pragmas` | `label`         | `None`  | Optional `.adc` file. |

**Action graph:** `AdaCompileInterface` (only if main has a spec) + `AdaCompileFull` for main + `AdaBind` + `AdaCompileFull` for the binder body + `AdaLink`.

## `ada_test`

Identical to `ada_binary` in shape, but registered as a Bazel test target.
Test passes iff the binary exits 0.

Same attribute set as `ada_binary`.

## `ada_shared_library`

Produces a `.so` (or platform equivalent) and exposes `CcInfo` so
`cc_binary` / `cc_library` can depend on it. Every unit is compiled with
`-fPIC`; the binder runs in library mode (`gnatbind -n -a -L<name>`) so
elaboration auto-runs on `.so` load via `pragma Linker_Constructor`. The
binary statically links libgnat (via `libgnat_pic.a`) so consumers don't
need an Ada runtime at runtime.

| Attribute        | Type            | Default | Description |
|------------------|-----------------|---------|-------------|
| `srcs`           | `label_list`    | required| `.ads`/`.adb` source files. |
| `deps`           | `label_list`    | `[]`    | `ada_library` deps. Their objects must be PIC-compatible to link cleanly into the shared library. |
| `copts`          | `string_list`   | `[]`    | Compiler flags. `-fPIC` is always added before these. |
| `config_pragmas` | `label`         | `None`  | Optional `.adc` file. |
| `lib_name`       | `string`        | label name | Name passed to `gnatbind -L` for elaboration symbols. The exported entry points are named `<lib_name>init` and `<lib_name>final`. |

C-side header: write it by hand. Mark Ada subprograms `pragma Export (C, …, External_Name => "…")` so the symbols have stable names, then declare them in your `.h`. The C consumer doesn't need to call init/final — `gnatbind -a` registers them as constructors/destructors that fire on `.so` load/unload.

**Action graph:** `AdaCompileFull` (PIC) for each unit + `AdaBind` in library mode + `AdaCompileFull` for the binder body + `AdaLinkShared`.

## `ada_static_library`

Same compile + library-mode bind as `ada_shared_library`, but the link
step is replaced by `ar rcs` to produce a `.a` archive. Exposed via
`CcInfo` as a `pic_static_library`. Useful when the consumer wants
static linking (e.g., a `cc_binary` building a single statically-linked
executable).

Same attribute set as `ada_shared_library`. **Action graph:**
`AdaCompileFull` (PIC) for each unit + `AdaBind` in library mode +
`AdaCompileFull` for the binder body + `AdaArchive`.

## `AdaInfo` provider

| Field                         | Type            | Use |
|-------------------------------|-----------------|-----|
| `transitive_spec_alis`        | `depset[File]`  | Spec ALIs reachable through deps; downstream compile inputs. |
| `transitive_body_alis`        | `depset[File]`  | Body ALIs reachable through deps; binder inputs. |
| `transitive_objects`          | `depset[File]`  | Body `.o` files; link inputs. |
| `transitive_specs`            | `depset[File]`  | `.ads` source files reachable through deps. |
| `transitive_exported_bodies`  | `depset[File]`  | `.adb` sources from libs marked `exports_bodies = True`; compile inputs for cross-lib generic instantiation. |
| `transitive_srcdirs`          | `depset[str]`   | Dirs to add via `-I` for `.ads` source lookup. |
| `transitive_spec_alidirs`     | `depset[str]`   | Dirs containing spec ALIs. |
| `transitive_body_alidirs`     | `depset[str]`   | Dirs containing body ALIs. |
| `direct_spec_alis`            | `depset[File]`  | Spec ALIs emitted by this target only. |
| `direct_body_alis`            | `depset[File]`  | Body ALIs emitted by this target only. |
| `direct_objects`              | `depset[File]`  | Body `.o` files emitted by this target only. |
| `units`                       | `list[struct]`  | Per-unit `(stem, spec, body, spec_ali, body_ali, object)`. |

## Toolchains

The toolchain type is `@rules_ada//ada:toolchain_type`. The rule definition
that produces an `AdaToolchainInfo` is `ada_toolchain` from
`@rules_ada//ada:toolchain.bzl`.

### `ada_toolchain` attributes

| Attribute            | Type     | Default      | Description |
|----------------------|----------|--------------|-------------|
| `gcc`                | `label`  | required     | GNAT-enabled gcc driver. |
| `gnatbind`           | `label`  | required     | gnatbind binary. |
| `gnatls`             | `label`  | required     | gnatls binary. |
| `runtime_specs`      | `label`  | required     | Filegroup of `adainclude/*.ads`. |
| `runtime_alis`       | `label`  | required     | Filegroup of `adalib/*.ali`. |
| `runtime_libs`       | `label`  | required     | Filegroup of libgnat / libgnarl artifacts. |
| `all_files`          | `label`  | `None`       | Every file under the toolchain root. Fed as inputs to every action so the sandbox sees the full toolchain tree (`cc1`, `gnat1`, `collect2`, `ld`, etc.). |
| `extra_link_flags`   | `string_list` | `["-lgnat"]` | Trailing flags passed at link time. |
| `target_triple`      | `string` | required     | The toolchain's target triple, e.g. `x86_64-pc-linux-gnu`. |
| `use_host_env`       | `bool`   | `False`      | If `True`, actions inherit the host shell env via `use_default_shell_env = True`. Use only for non-hermetic toolchains (system GNAT) that need to find tools like `ld` via host PATH. |

### `AdaToolchainInfo` provider

Same shape as the rule attributes plus `bin_dir` (the directory containing
`gcc`, used to set `PATH` in actions when `use_host_env = False`).
