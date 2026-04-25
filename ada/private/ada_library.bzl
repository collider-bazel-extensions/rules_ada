"""ada_library rule."""

load("//ada:providers.bzl", "AdaInfo", "merge_ada_infos")
load(":compile.bzl", "compile_full", "compile_interface")
load(":unit_naming.bzl", "collect_units")

def _ada_library_impl(ctx):
    toolchain = ctx.toolchains["//ada:toolchain_type"].adainfo
    deps_view = merge_ada_infos(ctx.attr.deps)

    explicit_subunits = ctx.files.subunits
    explicit_subunit_set = {f.path: True for f in explicit_subunits}
    auto_srcs = [s for s in ctx.files.srcs if s.path not in explicit_subunit_set]
    units_by_stem, heuristic_subunits = collect_units(auto_srcs)
    subunits = heuristic_subunits + explicit_subunits
    all_specs = [u.spec for u in units_by_stem.values() if u.spec != None]
    all_bodies = [u.body for u in units_by_stem.values() if u.body != None]

    direct_spec_alis = []
    direct_body_alis = []
    direct_objects = []
    units_out = []

    for stem in sorted(units_by_stem.keys()):
        u = units_by_stem[stem]
        sibling_sources = (
            [s for s in all_specs if s != u.spec] +
            [b for b in all_bodies if b != u.body] +
            subunits
        )

        spec_ali = None
        body_ali = None
        obj = None

        config_pragmas_file = ctx.file.config_pragmas

        if u.spec != None and u.body != None:
            spec_ali = compile_interface(
                ctx = ctx,
                toolchain = toolchain,
                deps_view = deps_view,
                sibling_sources = sibling_sources,
                stem = stem,
                spec = u.spec,
                copts = ctx.attr.copts,
                config_pragmas = config_pragmas_file,
            )
            direct_spec_alis.append(spec_ali)

        if u.body != None or u.spec != None:
            body_ali, obj = compile_full(
                ctx = ctx,
                toolchain = toolchain,
                deps_view = deps_view,
                sibling_sources = sibling_sources,
                stem = stem,
                spec = u.spec,
                body = u.body,
                copts = ctx.attr.copts,
                config_pragmas = config_pragmas_file,
            )
            direct_body_alis.append(body_ali)
            direct_objects.append(obj)

        units_out.append(struct(
            stem = stem,
            spec = u.spec,
            body = u.body,
            spec_ali = spec_ali,
            body_ali = body_ali,
            object = obj,
        ))

    direct_srcdirs = sorted({s.dirname: None for s in all_specs}.keys())
    direct_spec_alidirs = sorted({a.dirname: None for a in direct_spec_alis}.keys())
    direct_body_alidirs = sorted({a.dirname: None for a in direct_body_alis}.keys())

    direct_exported_bodies = (all_bodies + subunits) if ctx.attr.exports_bodies else []

    return [
        DefaultInfo(files = depset(direct_spec_alis + direct_body_alis + direct_objects)),
        AdaInfo(
            transitive_spec_alis = depset(direct_spec_alis, transitive = [deps_view.transitive_spec_alis]),
            transitive_body_alis = depset(direct_body_alis, transitive = [deps_view.transitive_body_alis]),
            transitive_objects = depset(direct_objects, transitive = [deps_view.transitive_objects]),
            transitive_specs = depset(all_specs, transitive = [deps_view.transitive_specs]),
            transitive_exported_bodies = depset(direct_exported_bodies, transitive = [deps_view.transitive_exported_bodies]),
            transitive_srcdirs = depset(direct_srcdirs, transitive = [deps_view.transitive_srcdirs]),
            transitive_spec_alidirs = depset(direct_spec_alidirs, transitive = [deps_view.transitive_spec_alidirs]),
            transitive_body_alidirs = depset(direct_body_alidirs, transitive = [deps_view.transitive_body_alidirs]),
            direct_spec_alis = depset(direct_spec_alis),
            direct_body_alis = depset(direct_body_alis),
            direct_objects = depset(direct_objects),
            units = units_out,
        ),
    ]

ada_library = rule(
    implementation = _ada_library_impl,
    attrs = {
        "srcs": attr.label_list(allow_files = [".ads", ".adb"], mandatory = True),
        "subunits": attr.label_list(
            allow_files = [".adb"],
            doc = "Body files that are `separate` subunits, listed explicitly to bypass " +
                  "the hyphen-stem heuristic. Use when filenames don't follow GNAT's " +
                  "default convention (e.g., `Source_File_Name` pragma in a `gnat.adc`). " +
                  "Files listed here MUST also appear in `srcs`. They flow as inputs to " +
                  "their parent unit's compile but get no standalone compile action.",
        ),
        "deps": attr.label_list(providers = [AdaInfo]),
        "exports_bodies": attr.bool(
            default = False,
            doc = "If True, this library's body sources flow into downstream compile inputs. " +
                  "Set this on libraries whose public API exposes generics, since cross-unit " +
                  "generic instantiation requires the generic body at the instantiation site's " +
                  "compile time. Increases incrementality cost downstream — only enable when needed.",
        ),
        "copts": attr.string_list(
            doc = "Additional compiler flags applied to every compile action for this " +
                  "target's units (both interface and full compiles). Appended after the " +
                  "rule's own structural flags so user values win on conflict.",
        ),
        "config_pragmas": attr.label(
            allow_single_file = [".adc"],
            doc = "Optional `.adc` file passed via `gcc -gnatec=` to every compile in this " +
                  "target. Use it for project-wide configuration pragmas (e.g., " +
                  "`pragma Restrictions`, `pragma Warnings`).",
        ),
    },
    toolchains = ["//ada:toolchain_type"],
    provides = [AdaInfo],
)
