"""ada_shared_library — produces a .so/.dylib/.dll and exposes CcInfo
so cc_binary/cc_library can link against it."""

load("@rules_cc//cc/common:cc_common.bzl", "cc_common")
load("@rules_cc//cc/common:cc_info.bzl", "CcInfo")
load("@rules_cc//cc:find_cc_toolchain.bzl", "find_cc_toolchain", "use_cc_toolchain")
load("//ada:providers.bzl", "AdaInfo", "merge_ada_infos")
load(":bind.bzl", "bind_library")
load(":compile.bzl", "compile_full")
load(":link.bzl", "link_shared")
load(":unit_naming.bzl", "collect_units")

def _shared_library_filename(label_name, ext):
    return "lib%s.%s" % (label_name, ext)

def _ada_shared_library_impl(ctx):
    toolchain = ctx.toolchains["//ada:toolchain_type"].adainfo
    deps_view = merge_ada_infos(ctx.attr.deps)

    units_by_stem, subunits = collect_units(ctx.files.srcs)
    if subunits:
        # Subunits are valid in srcs (they flow into parent compiles), no error here.
        pass
    all_specs = [u.spec for u in units_by_stem.values() if u.spec != None]
    all_bodies = [u.body for u in units_by_stem.values() if u.body != None]

    pic_copts = ["-fPIC"] + ctx.attr.copts
    config_pragmas_file = ctx.file.config_pragmas

    direct_alis = []
    direct_objects = []

    for stem in sorted(units_by_stem.keys()):
        u = units_by_stem[stem]
        sibling_sources = (
            [s for s in all_specs if s != u.spec] +
            [b for b in all_bodies if b != u.body] +
            subunits
        )
        if u.body != None or u.spec != None:
            ali, obj = compile_full(
                ctx = ctx,
                toolchain = toolchain,
                deps_view = deps_view,
                sibling_sources = sibling_sources,
                stem = stem,
                spec = u.spec,
                body = u.body,
                copts = pic_copts,
                config_pragmas = config_pragmas_file,
            )
            direct_alis.append(ali)
            direct_objects.append(obj)

    if not direct_alis:
        fail("rules_ada: %s has no compilable units" % ctx.label)

    lib_name = ctx.attr.lib_name or ctx.label.name
    bind_deps_view = struct(
        transitive_spec_alis = depset(transitive = [deps_view.transitive_spec_alis]),
        transitive_body_alis = depset(direct_alis, transitive = [deps_view.transitive_body_alis]),
        transitive_objects = depset(direct_objects, transitive = [deps_view.transitive_objects]),
        transitive_specs = depset(all_specs, transitive = [deps_view.transitive_specs]),
        transitive_exported_bodies = depset(transitive = [deps_view.transitive_exported_bodies]),
        transitive_srcdirs = depset(
            sorted({s.dirname: None for s in all_specs}.keys()),
            transitive = [deps_view.transitive_srcdirs],
        ),
        transitive_spec_alidirs = depset(transitive = [deps_view.transitive_spec_alidirs]),
        transitive_body_alidirs = depset(
            sorted({a.dirname: None for a in direct_alis}.keys()),
            transitive = [deps_view.transitive_body_alidirs],
        ),
    )

    binder_ads, binder_adb = bind_library(
        ctx = ctx,
        toolchain = toolchain,
        deps_view = bind_deps_view,
        unit_alis = direct_alis,
        lib_name = lib_name,
    )

    _, binder_obj = compile_full(
        ctx = ctx,
        toolchain = toolchain,
        deps_view = bind_deps_view,
        sibling_sources = [],
        stem = "b__" + lib_name,
        spec = binder_ads,
        body = binder_adb,
        copts = pic_copts,
    )

    output_so = ctx.actions.declare_file(_shared_library_filename(ctx.label.name, "so"))
    link_shared(
        ctx = ctx,
        toolchain = toolchain,
        deps_view = bind_deps_view,
        binder_obj = binder_obj,
        output = output_so,
        soname = output_so.basename,
    )

    cc_toolchain = find_cc_toolchain(ctx)
    feature_configuration = cc_common.configure_features(
        ctx = ctx,
        cc_toolchain = cc_toolchain,
        requested_features = ctx.features,
        unsupported_features = ctx.disabled_features,
    )
    library_to_link = cc_common.create_library_to_link(
        actions = ctx.actions,
        feature_configuration = feature_configuration,
        cc_toolchain = cc_toolchain,
        dynamic_library = output_so,
    )
    linker_input = cc_common.create_linker_input(
        owner = ctx.label,
        libraries = depset([library_to_link]),
    )
    cc_info = CcInfo(
        linking_context = cc_common.create_linking_context(
            linker_inputs = depset([linker_input]),
        ),
    )

    return [
        DefaultInfo(files = depset([output_so])),
        cc_info,
    ]

ada_shared_library = rule(
    implementation = _ada_shared_library_impl,
    attrs = {
        "srcs": attr.label_list(allow_files = [".ads", ".adb"], mandatory = True),
        "deps": attr.label_list(providers = [AdaInfo]),
        "copts": attr.string_list(
            doc = "Additional compiler flags. `-fPIC` is always added before these.",
        ),
        "config_pragmas": attr.label(
            allow_single_file = [".adc"],
            doc = "Optional `.adc` file passed via `gcc -gnatec=` to every compile.",
        ),
        "lib_name": attr.string(
            doc = "Name passed to `gnatbind -L` for elaboration symbols. " +
                  "Defaults to the target's label name.",
        ),
    },
    toolchains = ["//ada:toolchain_type"] + use_cc_toolchain(),
    fragments = ["cpp"],
    provides = [CcInfo],
)
