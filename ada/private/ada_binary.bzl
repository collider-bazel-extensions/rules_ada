"""ada_binary rule."""

load(":ada_executable.bzl", "EXECUTABLE_ATTRS", "build_ada_executable")

def _ada_binary_impl(ctx):
    output, toolchain = build_ada_executable(ctx)
    runfiles = ctx.runfiles(
        files = ctx.files.data,
        transitive_files = toolchain.runtime_libs,
    )
    for d in ctx.attr.data:
        runfiles = runfiles.merge(d[DefaultInfo].default_runfiles)
    return [DefaultInfo(
        executable = output,
        files = depset([output]),
        runfiles = runfiles,
    )]

ada_binary = rule(
    implementation = _ada_binary_impl,
    attrs = EXECUTABLE_ATTRS,
    toolchains = ["//ada:toolchain_type"],
    executable = True,
)
