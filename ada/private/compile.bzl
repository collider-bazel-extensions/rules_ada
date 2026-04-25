"""Spec-interface and full compile actions for Ada units.

For units that have both spec and body, we produce:
  - an "interface" ALI via `-gnatc` on the spec → spec_dir/<stem>.ali (no object)
  - a "full" ALI by compiling the body          → body_dir/<stem>.ali + .o

For spec-only units (no body anywhere), we do one compile of the spec
without `-gnatc`. That produces a regular linkable ALI + object placed in
body_dir — those units have no separate "interface" output.
"""

load(":action_env.bzl", "action_env_kwargs")

def _build_args(ctx, toolchain, deps_view, sibling_sources, extra_flags, copts, config_pragmas, output_obj_path, primary_path):
    sibling_dir_set = {}
    for s in sibling_sources:
        sibling_dir_set[s.dirname] = None

    args = ctx.actions.args()
    args.add("-c")
    args.add("-x", "ada")
    args.add_all(extra_flags)
    args.add("-o", output_obj_path)
    args.add_all(deps_view.transitive_srcdirs, format_each = "-I%s")
    args.add_all(deps_view.transitive_spec_alidirs, format_each = "-I%s")
    args.add_all(deps_view.transitive_body_alidirs, format_each = "-I%s")
    args.add("-I" + toolchain.runtime_specdir)
    args.add("-I" + toolchain.runtime_alidir)
    for d in sorted(sibling_dir_set.keys()):
        args.add("-I" + d)
    if config_pragmas != None:
        args.add("-gnatec=" + config_pragmas.path)
    args.add_all(copts)
    args.add(primary_path)
    return args

def compile_interface(ctx, toolchain, deps_view, sibling_sources, stem, spec, copts = [], config_pragmas = None, out_subdir = None):
    """Spec-only `-gnatc` compile. Used only for body-having units; emits .ali, no .o."""
    if out_subdir == None:
        out_subdir = "_ada/%s/spec" % ctx.label.name
    ali = ctx.actions.declare_file("%s/%s.ali" % (out_subdir, stem))
    phantom_obj_path = "%s/%s.o" % (ali.dirname, stem)

    args = _build_args(
        ctx, toolchain, deps_view, sibling_sources,
        extra_flags = ["-gnatc"],
        copts = copts,
        config_pragmas = config_pragmas,
        output_obj_path = phantom_obj_path,
        primary_path = spec.path,
    )

    direct_inputs = [spec] + sibling_sources
    if config_pragmas != None:
        direct_inputs.append(config_pragmas)

    ctx.actions.run(
        executable = toolchain.gcc,
        arguments = [args],
        inputs = depset(
            direct = direct_inputs,
            transitive = [
                deps_view.transitive_specs,
                deps_view.transitive_spec_alis,
                deps_view.transitive_exported_bodies,
                toolchain.runtime_specs,
                toolchain.all_files,
            ],
        ),
        outputs = [ali],
        mnemonic = "AdaCompileInterface",
        progress_message = "Compiling Ada interface %s" % stem,
        **action_env_kwargs(toolchain)
    )
    return ali

def compile_full(ctx, toolchain, deps_view, sibling_sources, stem, spec, body, copts = [], config_pragmas = None, out_subdir = None):
    """Full compile. `body` if present (body-having unit) else `spec` (spec-only unit).
    Produces both .ali and .o."""
    primary = body if body != None else spec
    if primary == None:
        fail("rules_ada: compile_full needs at least a spec or body for %s" % stem)

    if out_subdir == None:
        out_subdir = "_ada/%s/body" % ctx.label.name
    ali = ctx.actions.declare_file("%s/%s.ali" % (out_subdir, stem))
    obj = ctx.actions.declare_file("%s/%s.o" % (out_subdir, stem))

    args = _build_args(
        ctx, toolchain, deps_view, sibling_sources,
        extra_flags = [],
        copts = copts,
        config_pragmas = config_pragmas,
        output_obj_path = obj.path,
        primary_path = primary.path,
    )

    direct_inputs = [primary] + sibling_sources
    if body != None and spec != None:
        direct_inputs.append(spec)
    if config_pragmas != None:
        direct_inputs.append(config_pragmas)

    ctx.actions.run(
        executable = toolchain.gcc,
        arguments = [args],
        inputs = depset(
            direct = direct_inputs,
            transitive = [
                deps_view.transitive_specs,
                deps_view.transitive_spec_alis,
                deps_view.transitive_exported_bodies,
                toolchain.runtime_specs,
                toolchain.all_files,
            ],
        ),
        outputs = [ali, obj],
        mnemonic = "AdaCompileFull",
        progress_message = "Compiling Ada %s %s" % ("body" if body != None else "spec", stem),
        **action_env_kwargs(toolchain)
    )
    return ali, obj
