"""Shared executable builder used by ada_binary and ada_test."""

load("//ada:providers.bzl", "AdaInfo", "merge_ada_infos")
load(":bind.bzl", "bind")
load(":compile.bzl", "compile_full", "compile_interface")
load(":link.bzl", "link")
load(":unit_naming.bzl", "collect_units")

def build_ada_executable(ctx):
    toolchain = ctx.toolchains["//ada:toolchain_type"].adainfo
    deps_view = merge_ada_infos(ctx.attr.deps)

    units_by_stem, subunits = collect_units(ctx.files.srcs)
    if subunits:
        fail("rules_ada: %s subunits are only valid in ada_library; got %s" %
             (ctx.label, [s.path for s in subunits]))
    if len(units_by_stem) != 1:
        fail("rules_ada: %s expects exactly one main unit, got %d" %
             (ctx.label, len(units_by_stem)))
    main_stem = list(units_by_stem.keys())[0]
    main_u = units_by_stem[main_stem]
    if main_u.body == None:
        fail("rules_ada: %s main %s must have a body (.adb)" % (ctx.label, main_stem))

    config_pragmas_file = ctx.file.config_pragmas

    main_spec_ali = None
    if main_u.spec != None:
        main_spec_ali = compile_interface(
            ctx = ctx,
            toolchain = toolchain,
            deps_view = deps_view,
            sibling_sources = [],
            stem = main_stem,
            spec = main_u.spec,
            copts = ctx.attr.copts,
            config_pragmas = config_pragmas_file,
        )

    main_body_ali, main_obj = compile_full(
        ctx = ctx,
        toolchain = toolchain,
        deps_view = deps_view,
        sibling_sources = [],
        stem = main_stem,
        spec = main_u.spec,
        body = main_u.body,
        copts = ctx.attr.copts,
        config_pragmas = config_pragmas_file,
    )

    spec_alis_for_binary = [main_spec_ali] if main_spec_ali != None else []
    spec_alidirs_for_binary = [main_spec_ali.dirname] if main_spec_ali != None else []

    binary_deps_view = struct(
        transitive_spec_alis = depset(spec_alis_for_binary, transitive = [deps_view.transitive_spec_alis]),
        transitive_body_alis = depset([main_body_ali], transitive = [deps_view.transitive_body_alis]),
        transitive_objects = depset([main_obj], transitive = [deps_view.transitive_objects]),
        transitive_specs = depset(transitive = [deps_view.transitive_specs]),
        transitive_exported_bodies = depset(transitive = [deps_view.transitive_exported_bodies]),
        transitive_srcdirs = depset(transitive = [deps_view.transitive_srcdirs]),
        transitive_spec_alidirs = depset(spec_alidirs_for_binary, transitive = [deps_view.transitive_spec_alidirs]),
        transitive_body_alidirs = depset([main_body_ali.dirname], transitive = [deps_view.transitive_body_alidirs]),
    )

    binder_ads, binder_adb = bind(
        ctx = ctx,
        toolchain = toolchain,
        deps_view = binary_deps_view,
        main_ali = main_body_ali,
        main_stem = main_stem,
    )

    _, binder_obj = compile_full(
        ctx = ctx,
        toolchain = toolchain,
        deps_view = binary_deps_view,
        sibling_sources = [],
        stem = "b__" + main_stem,
        spec = binder_ads,
        body = binder_adb,
    )

    output = ctx.actions.declare_file(ctx.label.name)
    link(
        ctx = ctx,
        toolchain = toolchain,
        deps_view = binary_deps_view,
        binder_obj = binder_obj,
        output = output,
    )
    return output, toolchain

EXECUTABLE_ATTRS = {
    "srcs": attr.label_list(allow_files = [".ads", ".adb"], mandatory = True),
    "deps": attr.label_list(providers = [AdaInfo]),
    "data": attr.label_list(
        allow_files = True,
        doc = "Runtime data files made available via runfiles.",
    ),
    "copts": attr.string_list(
        doc = "Additional compiler flags applied to every compile action for this " +
              "target's main and binder. Appended after the rule's structural flags.",
    ),
    "config_pragmas": attr.label(
        allow_single_file = [".adc"],
        doc = "Optional `.adc` file passed via `gcc -gnatec=` to every compile in this " +
              "target.",
    ),
}
