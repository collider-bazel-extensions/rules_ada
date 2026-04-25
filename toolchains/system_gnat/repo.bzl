"""Repository rule that probes the host GNAT install via gnatls."""

_FIXED_EPOCH = "200001010000.00"  # YYYYMMDDhhmm.SS for `touch -t`

def _which(repository_ctx, name):
    p = repository_ctx.which(name)
    if p == None:
        fail("rules_ada: %s not found on PATH; install gcc-gnat" % name)
    return p

def _gnatls_paths(repository_ctx, gnatls):
    res = repository_ctx.execute([gnatls, "-v"])
    if res.return_code != 0:
        fail("rules_ada: gnatls -v failed: %s" % res.stderr)
    src_path = None
    obj_path = None
    section = None
    for raw in res.stdout.splitlines():
        line = raw.strip()
        if line.startswith("Source Search Path"):
            section = "src"
            continue
        if line.startswith("Object Search Path"):
            section = "obj"
            continue
        if line.startswith("Project Search Path") or line == "":
            section = None
            continue
        if section == "src" and line.startswith("/"):
            src_path = line
        if section == "obj" and line.startswith("/"):
            obj_path = line
    if src_path == None or obj_path == None:
        fail("rules_ada: could not parse adainclude/adalib paths from gnatls -v")
    return src_path, obj_path

def _libgnat_dir(repository_ctx, gcc):
    res = repository_ctx.execute([gcc, "-print-file-name=libgnat.so"])
    if res.return_code != 0 or not res.stdout.strip().startswith("/"):
        return None
    libpath = res.stdout.strip()
    return libpath.rsplit("/", 1)[0]

def _list_dir(repository_ctx, src_dir):
    res = repository_ctx.execute(["ls", src_dir])
    if res.return_code != 0:
        fail("rules_ada: cannot list %s" % src_dir)
    return [f for f in res.stdout.split("\n") if f]

def _symlink_tree(repository_ctx, src_dir, dst_dir, files):
    repository_ctx.execute(["mkdir", "-p", dst_dir])
    for f in files:
        repository_ctx.symlink(src_dir + "/" + f, dst_dir + "/" + f)

def _normalize_mtimes(repository_ctx, dst_dir):
    repository_ctx.execute([
        "find",
        dst_dir,
        "-exec",
        "touch",
        "-h",
        "-t",
        _FIXED_EPOCH,
        "{}",
        "+",
    ])

def _quote_list(items, prefix):
    return ",\n        ".join(['"%s%s"' % (prefix, f) for f in items])

def _system_gnat_impl(repository_ctx):
    gcc = _which(repository_ctx, "gcc")
    gnatbind = _which(repository_ctx, "gnatbind")
    gnatls = _which(repository_ctx, "gnatls")

    adainclude, adalib = _gnatls_paths(repository_ctx, gnatls)
    libgnatdir = _libgnat_dir(repository_ctx, gcc) or adalib

    spec_names = [f for f in _list_dir(repository_ctx, adainclude) if f.endswith(".ads")]
    ali_names = [f for f in _list_dir(repository_ctx, adalib) if f.endswith(".ali")]
    lib_names = [f for f in _list_dir(repository_ctx, libgnatdir)
                 if f.startswith("libgnat") or f.startswith("libgnarl")]

    _symlink_tree(repository_ctx, adainclude, "adainclude", spec_names)
    _symlink_tree(repository_ctx, adalib, "adalib", ali_names)
    _symlink_tree(repository_ctx, libgnatdir, "lib", lib_names)
    _normalize_mtimes(repository_ctx, "adainclude")

    repository_ctx.symlink(gcc, "bin/gcc")
    repository_ctx.symlink(gnatbind, "bin/gnatbind")
    repository_ctx.symlink(gnatls, "bin/gnatls")
    ar = _which(repository_ctx, "ar")
    repository_ctx.symlink(ar, "bin/ar")

    repository_ctx.file("BUILD.bazel", """
load("@rules_ada//ada:toolchain.bzl", "ada_toolchain")

package(default_visibility = ["//visibility:public"])

filegroup(name = "gcc",      srcs = ["bin/gcc"])
filegroup(name = "gnatbind", srcs = ["bin/gnatbind"])
filegroup(name = "gnatls",   srcs = ["bin/gnatls"])

filegroup(
    name = "all_files",
    srcs = glob(["**"], exclude = ["BUILD.bazel", "WORKSPACE", "MODULE.bazel"]),
)

filegroup(
    name = "runtime_specs",
    srcs = [
        {spec_files}
    ],
)

filegroup(
    name = "runtime_alis",
    srcs = [
        {ali_files}
    ],
)

filegroup(
    name = "runtime_libs",
    srcs = [
        {lib_files}
    ],
)

ada_toolchain(
    name = "ada_toolchain",
    gcc = ":gcc",
    gnatbind = ":gnatbind",
    gnatls = ":gnatls",
    all_files = ":all_files",
    runtime_specs = ":runtime_specs",
    runtime_alis = ":runtime_alis",
    runtime_libs = ":runtime_libs",
    use_host_env = True,
    extra_link_flags = [
        "-l:libgnat_pic.a",
        "-lpthread",
        "-ldl",
    ],
    target_triple = "host",
)

toolchain(
    name = "toolchain",
    toolchain = ":ada_toolchain",
    toolchain_type = "@rules_ada//ada:toolchain_type",
)
""".format(
        spec_files = _quote_list(spec_names, "adainclude/"),
        ali_files = _quote_list(ali_names, "adalib/"),
        lib_files = _quote_list(lib_names, "lib/"),
    ))

system_gnat_repo = repository_rule(
    implementation = _system_gnat_impl,
    local = True,
)
