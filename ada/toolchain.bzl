"""ada_toolchain rule and AdaToolchainInfo provider."""

AdaToolchainInfo = provider(
    doc = "Concrete Ada toolchain.",
    fields = {
        "gcc": "File: GNAT-enabled gcc driver",
        "gnatbind": "File: gnatbind",
        "gnatls": "File: gnatls",
        "all_files": "depset[File]: every file in the toolchain tree, used as action inputs",
        "runtime_specs": "depset[File]: adainclude/*.ads",
        "runtime_specdir": "str: dir to add via -I for runtime specs",
        "runtime_alidir": "str: dir to add via -aO for runtime ALIs",
        "runtime_libs": "depset[File]: libgnat etc.",
        "runtime_libdir": "str: dir to add via -L when linking",
        "bin_dir": "str: dir to put on PATH for collect2/ld discovery",
        "use_host_env": "bool: if True, actions use_default_shell_env (escape hatch for non-hermetic toolchains)",
        "extra_link_flags": "list[str]",
        "target_triple": "str",
    },
)

def _first_dirname(files, what):
    if not files:
        fail("rules_ada: ada_toolchain.%s is empty" % what)
    return files[0].dirname

def _ada_toolchain_impl(ctx):
    return [platform_common.ToolchainInfo(
        adainfo = AdaToolchainInfo(
            gcc = ctx.executable.gcc,
            gnatbind = ctx.executable.gnatbind,
            gnatls = ctx.executable.gnatls,
            all_files = depset(ctx.files.all_files),
            runtime_specs = depset(ctx.files.runtime_specs),
            runtime_specdir = _first_dirname(ctx.files.runtime_specs, "runtime_specs"),
            runtime_alidir = _first_dirname(ctx.files.runtime_alis, "runtime_alis"),
            runtime_libs = depset(ctx.files.runtime_libs),
            runtime_libdir = _first_dirname(ctx.files.runtime_libs, "runtime_libs"),
            bin_dir = ctx.executable.gcc.dirname,
            use_host_env = ctx.attr.use_host_env,
            extra_link_flags = ctx.attr.extra_link_flags,
            target_triple = ctx.attr.target_triple,
        ),
    )]

ada_toolchain = rule(
    implementation = _ada_toolchain_impl,
    attrs = {
        "gcc": attr.label(executable = True, cfg = "exec", allow_single_file = True, mandatory = True),
        "gnatbind": attr.label(executable = True, cfg = "exec", allow_single_file = True, mandatory = True),
        "gnatls": attr.label(executable = True, cfg = "exec", allow_single_file = True, mandatory = True),
        "all_files": attr.label(allow_files = True),
        "runtime_specs": attr.label(allow_files = [".ads"], mandatory = True),
        "runtime_alis": attr.label(allow_files = [".ali"], mandatory = True),
        "runtime_libs": attr.label(allow_files = True, mandatory = True),
        "extra_link_flags": attr.string_list(default = ["-lgnat"]),
        "target_triple": attr.string(mandatory = True),
        "use_host_env": attr.bool(
            default = False,
            doc = "If True, actions inherit the host shell env (use_default_shell_env). " +
                  "Use only for non-hermetic toolchains (system GNAT) that need to find " +
                  "tools like ld via host PATH. Hermetic toolchains should leave this False.",
        ),
    },
)
