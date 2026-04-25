"""Link an Ada binary or shared library."""

load(":action_env.bzl", "action_env_kwargs")

def _run_link(ctx, toolchain, deps_view, binder_obj, output, extra_flags, link_flags, mnemonic, progress, extra_objects = []):
    args = ctx.actions.args()
    args.add_all(extra_flags)
    args.add("-o", output.path)
    args.add(binder_obj.path)
    args.add_all(extra_objects)
    args.add_all(deps_view.transitive_objects)
    args.add("-L" + toolchain.runtime_libdir)
    args.add_all(link_flags)

    ctx.actions.run(
        executable = toolchain.gcc,
        arguments = [args],
        inputs = depset(
            direct = [binder_obj] + list(extra_objects),
            transitive = [
                deps_view.transitive_objects,
                toolchain.runtime_libs,
                toolchain.all_files,
            ],
        ),
        outputs = [output],
        mnemonic = mnemonic,
        progress_message = progress,
        **action_env_kwargs(toolchain)
    )

def link(ctx, toolchain, deps_view, binder_obj, output, extra_objects = []):
    _run_link(
        ctx, toolchain, deps_view,
        binder_obj = binder_obj,
        output = output,
        extra_flags = [],
        link_flags = toolchain.extra_link_flags,
        mnemonic = "AdaLink",
        progress = "Linking Ada binary %s" % output.short_path,
        extra_objects = extra_objects,
    )

# Shared libraries need PIC libgnat. Both shipped toolchains include libgnat_pic.a.
_SHARED_LINK_FLAGS = [
    "-l:libgnat_pic.a",
    "-lpthread",
    "-ldl",
]

def link_shared(ctx, toolchain, deps_view, binder_obj, output, soname, extra_objects = []):
    _run_link(
        ctx, toolchain, deps_view,
        binder_obj = binder_obj,
        output = output,
        extra_flags = ["-shared", "-Wl,-soname," + soname],
        link_flags = _SHARED_LINK_FLAGS,
        mnemonic = "AdaLinkShared",
        progress = "Linking Ada shared library %s" % output.short_path,
        extra_objects = extra_objects,
    )
