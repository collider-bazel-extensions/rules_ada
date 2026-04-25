"""Repository rule that fetches a hermetic FSF GNAT toolchain (Alire-built)."""

# Per-platform release artifacts. The triple and gcc version are probed from
# the extracted layout (lib/gcc/<triple>/<version>/) at repo-rule time so the
# table only carries the URL/sha256/strip_prefix.
_RELEASES_URL = "https://github.com/alire-project/GNAT-FSF-builds/releases/download"

_PLATFORMS = {
    "linux_x86_64": struct(
        url = _RELEASES_URL + "/gnat-15.2.0-1/gnat-x86_64-linux-15.2.0-1.tar.gz",
        sha256 = "4640d4b369833947ab1a156753f4db0ecd44b0f14410b5b2bc2a14df496604bb",
        strip_prefix = "gnat-x86_64-linux-15.2.0-1",
    ),
    "linux_aarch64": struct(
        url = _RELEASES_URL + "/gnat-15.2.0-1/gnat-aarch64-linux-15.2.0-1.tar.gz",
        sha256 = "54b1000a1b85f0ec241c71d375bae7602239875a01132f5dc5789a632870a1c7",
        strip_prefix = "gnat-aarch64-linux-15.2.0-1",
    ),
    "darwin_x86_64": struct(
        url = _RELEASES_URL + "/gnat-15.2.0-1/gnat-x86_64-darwin-15.2.0-1.tar.gz",
        sha256 = "fffe07e8732738a33e6ddc209debc23640e9e629584d30ad8ebee278999c7a0f",
        strip_prefix = "gnat-x86_64-darwin-15.2.0-1",
    ),
    "darwin_aarch64": struct(
        # macOS arm64 ships under a separate "macos-pre0" tag in the upstream releases.
        url = _RELEASES_URL + "/gnat-15.2.0-2-macos-pre0/gnat-aarch64-darwin-15.2.0-2-pre0.tar.gz",
        sha256 = "84d4c0b8e575e6ff4396cf455abac06512e6708b88b899db3bb78fc79f4b4691",
        strip_prefix = "gnat-aarch64-darwin-15.2.0-2-pre0",
    ),
    "windows_x86_64": struct(
        url = _RELEASES_URL + "/gnat-15.2.0-1/gnat-x86_64-windows64-15.2.0-1.tar.gz",
        sha256 = "346e2e00273fecc03bfa333f8e01131d05c8a87e57d4def2c61ae3018744785b",
        strip_prefix = "gnat-x86_64-windows64-15.2.0-1",
    ),
}

_BUILD_TEMPLATE = """\
load("@rules_ada//ada:toolchain.bzl", "ada_toolchain")

package(default_visibility = ["//visibility:public"])

filegroup(
    name = "all_files",
    srcs = glob(["**"], exclude = ["BUILD.bazel", "WORKSPACE", "MODULE.bazel"]),
)

filegroup(name = "gcc",      srcs = ["{gcc}"])
filegroup(name = "gnatbind", srcs = ["{gnatbind}"])
filegroup(name = "gnatls",   srcs = ["{gnatls}"])

filegroup(
    name = "runtime_specs",
    srcs = glob(["{rt_root}/adainclude/*.ads"]),
)

filegroup(
    name = "runtime_alis",
    srcs = glob(["{rt_root}/adalib/*.ali"]),
)

filegroup(
    name = "runtime_libs",
    srcs = glob([
        "{rt_root}/adalib/libgnat*",
        "{rt_root}/adalib/libgnarl*",
    ]),
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
    extra_link_flags = [
        "-Wl,-Bstatic",
        "-lgnat",
        "-Wl,-Bdynamic",
        "-lpthread",
        "-ldl",
    ],
    target_triple = "{triple}",
)

toolchain(
    name = "toolchain",
    toolchain = ":ada_toolchain",
    toolchain_type = "@rules_ada//ada:toolchain_type",
    exec_compatible_with = [
        "@platforms//os:{bazel_os}",
        "@platforms//cpu:{bazel_cpu}",
    ],
    target_compatible_with = [
        "@platforms//os:{bazel_os}",
        "@platforms//cpu:{bazel_cpu}",
    ],
)
"""

_OS_KEYS = {
    "linux": ("linux", "linux"),
    "darwin": ("darwin", "macos"),
    "windows": ("windows", "windows"),
}

_CPU_KEYS = {
    "x86_64": "x86_64",
    "aarch64": "aarch64",
}

def _detect_platform(repository_ctx):
    name = repository_ctx.os.name.lower()
    arch = repository_ctx.os.arch.lower()
    if "mac os" in name or "darwin" in name:
        os_key = "darwin"
    elif "windows" in name:
        os_key = "windows"
    elif "linux" in name:
        os_key = "linux"
    else:
        fail("rules_ada: unsupported OS for FSF GNAT: %s" % name)
    if arch in ("x86_64", "amd64"):
        arch_key = "x86_64"
    elif arch in ("aarch64", "arm64"):
        arch_key = "aarch64"
    else:
        fail("rules_ada: unsupported arch for FSF GNAT: %s" % arch)
    key = "%s_%s" % (os_key, arch_key)
    if key not in _PLATFORMS:
        fail("rules_ada: no FSF GNAT prebuilt available for %s/%s" % (os_key, arch_key))
    return key, os_key, arch_key

def _ls(repository_ctx, path):
    res = repository_ctx.execute(["ls", path])
    if res.return_code != 0:
        fail("rules_ada: cannot list %s: %s" % (path, res.stderr))
    return [line for line in res.stdout.split("\n") if line]

def _probe_triple_and_version(repository_ctx):
    triples = _ls(repository_ctx, "lib/gcc")
    if len(triples) != 1:
        fail("rules_ada: expected exactly one triple under lib/gcc, got %s" % triples)
    triple = triples[0]
    versions = _ls(repository_ctx, "lib/gcc/" + triple)
    if len(versions) != 1:
        fail("rules_ada: expected exactly one gcc version under lib/gcc/%s, got %s" %
             (triple, versions))
    return triple, versions[0]

def _impl(repository_ctx):
    plat_key, os_key, arch_key = _detect_platform(repository_ctx)
    info = _PLATFORMS[plat_key]
    repository_ctx.download_and_extract(
        url = info.url,
        sha256 = info.sha256,
        stripPrefix = info.strip_prefix,
    )
    triple, gcc_version = _probe_triple_and_version(repository_ctx)
    rt_root = "lib/gcc/%s/%s" % (triple, gcc_version)
    bin_ext = ".exe" if os_key == "windows" else ""
    bazel_os = _OS_KEYS[os_key][1]
    bazel_cpu = _CPU_KEYS[arch_key]
    repository_ctx.file("BUILD.bazel", _BUILD_TEMPLATE.format(
        rt_root = rt_root,
        triple = triple,
        gcc = "bin/gcc" + bin_ext,
        gnatbind = "bin/gnatbind" + bin_ext,
        gnatls = "bin/gnatls" + bin_ext,
        bazel_os = bazel_os,
        bazel_cpu = bazel_cpu,
    ))

fsf_gnat_repo = repository_rule(implementation = _impl)
