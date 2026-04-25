"""Fetches ada-toml as an external repo with a generated BUILD.

ada-toml is a real-world TOML parser written in pure Ada by Pierre-Marie
de Rodat. We use it as a smoke test for rules_ada on actual upstream code:
it exercises child packages (Toml.File_IO, Toml.Generic_Parse, ...),
cross-library generic instantiation (the checkers instantiate
Toml.Generic_Parse), and exception handling.
"""

_VERSION = "0.5"
_URL = "https://github.com/pmderodat/ada-toml/archive/refs/tags/v{}.tar.gz".format(_VERSION)
_SHA256 = "4ac51721bcf903d07fa7a1f3dae2173cd7c191e03c7c32ab945e91f79a4b1615"
_STRIP_PREFIX = "ada-toml-{}".format(_VERSION)

_BUILD = """\
load("@rules_ada//ada:defs.bzl", "ada_binary", "ada_library")

package(default_visibility = ["//visibility:public"])

ada_library(
    name = "toml",
    srcs = glob(["src/*.ads", "src/*.adb"]),
    # The library exports generic packages (Toml.Generic_Parse, Toml.Generic_Dump)
    # whose bodies must be visible at the cross-library instantiation site.
    exports_bodies = True,
)

ada_binary(
    name = "ada_toml_decode",
    srcs = ["src-checkers/ada_toml_decode.adb"],
    deps = [":toml"],
)

ada_binary(
    name = "ada_toml_encode",
    srcs = ["src-checkers/ada_toml_encode.adb"],
    deps = [":toml"],
)
"""

def _impl(repository_ctx):
    repository_ctx.download_and_extract(
        url = _URL,
        sha256 = _SHA256,
        stripPrefix = _STRIP_PREFIX,
    )
    repository_ctx.file("BUILD.bazel", _BUILD)

ada_toml_repo = repository_rule(implementation = _impl)
