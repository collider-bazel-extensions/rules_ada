"""Fetches AdaSAT — AdaCore's Ada SAT solver, used as a real-codebase smoke
test exercising generic packages (Adasat.Dpll, Adasat.Vectors, Adasat.Theory)
across library boundaries."""

_VERSION = "25.0.0"
_URL = "https://github.com/AdaCore/AdaSAT/archive/refs/tags/v{}.tar.gz".format(_VERSION)
_SHA256 = "b823969345cdd3678bf3cb1eb55592a0f74c2d99fc67303e187b4fbc960188a2"
_STRIP_PREFIX = "AdaSAT-{}".format(_VERSION)

_BUILD = """\
load("@rules_ada//ada:defs.bzl", "ada_binary", "ada_library", "ada_test")

package(default_visibility = ["//visibility:public"])

ada_library(
    name = "adasat",
    srcs = glob(["src/*.ads", "src/*.adb"]),
    # Adasat exports generic packages (Dpll, Vectors, Theory) — downstream
    # instantiation sites need the body sources visible at compile time.
    exports_bodies = True,
)

# Smoke test: a stand-alone test program that uses the solver.
ada_test(
    name = "simple_test",
    srcs = ["testsuite/tests/simple/test.adb"],
    deps = [":adasat"],
)

# A more substantial entry: the sudoku solver in the testsuite.
ada_binary(
    name = "sudoku",
    srcs = ["testsuite/tests/sudoku/sudoku.adb"],
    copts = ["-gnat2022"],  # uses Ada 2022 array literal syntax
    deps = [":adasat"],
)
"""

def _impl(repository_ctx):
    repository_ctx.download_and_extract(
        url = _URL,
        sha256 = _SHA256,
        stripPrefix = _STRIP_PREFIX,
    )
    repository_ctx.file("BUILD.bazel", _BUILD)

adasat_repo = repository_rule(implementation = _impl)
