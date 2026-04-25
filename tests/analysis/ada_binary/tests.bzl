"""Analysis tests for ada_binary and ada_test."""

load("@bazel_skylib//lib:unittest.bzl", "analysistest", "asserts")

def _action_counts(actions, mnemonic):
    return [a for a in actions if a.mnemonic == mnemonic]

# Body-only main → 1 full compile (main) + 1 bind + 1 full compile (binder) + 1 link.
def _binary_action_graph_test_impl(ctx):
    env = analysistest.begin(ctx)
    actions = analysistest.target_actions(env)
    asserts.equals(env, 0, len(_action_counts(actions, "AdaCompileInterface")))
    asserts.equals(env, 2, len(_action_counts(actions, "AdaCompileFull")))
    asserts.equals(env, 1, len(_action_counts(actions, "AdaBind")))
    asserts.equals(env, 1, len(_action_counts(actions, "AdaLink")))
    return analysistest.end(env)

binary_action_graph_test = analysistest.make(_binary_action_graph_test_impl)

# ada_binary should fail when srcs contains more than one main unit.
def _binary_multiple_units_failure_test_impl(ctx):
    env = analysistest.begin(ctx)
    asserts.expect_failure(env, "expects exactly one main unit")
    return analysistest.end(env)

binary_multiple_units_failure_test = analysistest.make(
    _binary_multiple_units_failure_test_impl,
    expect_failure = "expects exactly one main unit",
)

# ada_binary should reject subunits in srcs (subunits only valid in ada_library).
def _binary_subunit_failure_test_impl(ctx):
    env = analysistest.begin(ctx)
    asserts.expect_failure(env, "subunits are only valid in ada_library")
    return analysistest.end(env)

binary_subunit_failure_test = analysistest.make(
    _binary_subunit_failure_test_impl,
    expect_failure = "subunits are only valid in ada_library",
)

# ada_test produces an executable.
def _test_is_executable_test_impl(ctx):
    env = analysistest.begin(ctx)
    target = analysistest.target_under_test(env)
    asserts.true(env, target[DefaultInfo].files_to_run.executable != None,
                 "ada_test should produce an executable")
    return analysistest.end(env)

test_is_executable_test = analysistest.make(_test_is_executable_test_impl)
