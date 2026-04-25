"""Repository rule that fetches the AUnit testing framework source."""

_VERSION = "25.0.0"
_URL = "https://github.com/AdaCore/aunit/archive/refs/tags/v{}.tar.gz".format(_VERSION)
_SHA256 = "6468914556c95504e9aed1dd81a1fc9969e56416bd3bb25dd3bae3905f35d379"
_STRIP_PREFIX = "aunit-{}".format(_VERSION)

_BUILD = """\
load("@rules_ada//ada:defs.bzl", "ada_library")

package(default_visibility = ["//visibility:public"])

ada_library(
    name = "aunit",
    exports_bodies = True,
    srcs = glob(
        [
            "include/aunit/containers/*.ads",
            "include/aunit/containers/*.adb",
            "include/aunit/framework/*.ads",
            "include/aunit/framework/*.adb",
            "include/aunit/framework/calendar/*.ads",
            "include/aunit/framework/calendar/*.adb",
            "include/aunit/framework/fileio/*.ads",
            "include/aunit/framework/fileio/*.adb",
            "include/aunit/framework/nativememory/*.ads",
            "include/aunit/framework/nativememory/*.adb",
            "include/aunit/framework/fullexception/*.ads",
            "include/aunit/framework/fullexception/*.adb",
            "include/aunit/reporters/*.ads",
            "include/aunit/reporters/*.adb",
        ],
        allow_empty = True,
    ),
)
"""

def _impl(repository_ctx):
    repository_ctx.download_and_extract(
        url = _URL,
        sha256 = _SHA256,
        stripPrefix = _STRIP_PREFIX,
    )
    repository_ctx.file("BUILD.bazel", _BUILD)

aunit_repo = repository_rule(implementation = _impl)
