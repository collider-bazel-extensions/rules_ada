"""Analysis tests for ada_library."""

load("@bazel_skylib//lib:unittest.bzl", "analysistest", "asserts")
load("//ada:providers.bzl", "AdaInfo")

def _action_counts(actions, mnemonic):
    return [a for a in actions if a.mnemonic == mnemonic]

# Two body-having units → 2 interface compiles + 2 full compiles, no extras.
def _two_unit_actions_test_impl(ctx):
    env = analysistest.begin(ctx)
    actions = analysistest.target_actions(env)
    asserts.equals(env, 2, len(_action_counts(actions, "AdaCompileInterface")))
    asserts.equals(env, 2, len(_action_counts(actions, "AdaCompileFull")))
    asserts.equals(env, 0, len(_action_counts(actions, "AdaBind")))
    asserts.equals(env, 0, len(_action_counts(actions, "AdaLink")))
    return analysistest.end(env)

two_unit_actions_test = analysistest.make(_two_unit_actions_test_impl)

# Spec-only unit → no interface compile (would be redundant with full), 1 full.
def _spec_only_actions_test_impl(ctx):
    env = analysistest.begin(ctx)
    actions = analysistest.target_actions(env)
    asserts.equals(env, 0, len(_action_counts(actions, "AdaCompileInterface")))
    asserts.equals(env, 1, len(_action_counts(actions, "AdaCompileFull")))
    return analysistest.end(env)

spec_only_actions_test = analysistest.make(_spec_only_actions_test_impl)

# Subunit (separate body) → its own .adb does NOT get a standalone compile.
def _subunit_no_action_test_impl(ctx):
    env = analysistest.begin(ctx)
    actions = analysistest.target_actions(env)
    full = _action_counts(actions, "AdaCompileFull")
    # Just `parent` — `parent-child.adb` is a subunit, not a unit.
    asserts.equals(env, 1, len(full))
    asserts.equals(env, 1, len(_action_counts(actions, "AdaCompileInterface")))
    return analysistest.end(env)

subunit_no_action_test = analysistest.make(_subunit_no_action_test_impl)

# Subunit's source still flows as input to the parent's compile actions.
def _subunit_is_input_test_impl(ctx):
    env = analysistest.begin(ctx)
    actions = analysistest.target_actions(env)
    parent_full = [a for a in actions
                   if a.mnemonic == "AdaCompileFull" and "parent" in a.outputs.to_list()[0].path]
    asserts.equals(env, 1, len(parent_full))
    input_paths = [f.path for f in parent_full[0].inputs.to_list()]
    asserts.true(env,
                 any([p.endswith("parent-child.adb") for p in input_paths]),
                 "parent-child.adb should appear among parent's compile inputs")
    return analysistest.end(env)

subunit_is_input_test = analysistest.make(_subunit_is_input_test_impl)

# exports_bodies = True → AdaInfo.transitive_exported_bodies is non-empty.
def _exports_bodies_true_test_impl(ctx):
    env = analysistest.begin(ctx)
    target = analysistest.target_under_test(env)
    info = target[AdaInfo]
    bodies = info.transitive_exported_bodies.to_list()
    asserts.true(env, len(bodies) > 0,
                 "transitive_exported_bodies should be non-empty when exports_bodies=True")
    return analysistest.end(env)

exports_bodies_true_test = analysistest.make(_exports_bodies_true_test_impl)

# Default exports_bodies=False → transitive_exported_bodies is empty.
def _exports_bodies_default_test_impl(ctx):
    env = analysistest.begin(ctx)
    target = analysistest.target_under_test(env)
    info = target[AdaInfo]
    bodies = info.transitive_exported_bodies.to_list()
    asserts.equals(env, 0, len(bodies),
                   "transitive_exported_bodies should be empty when exports_bodies is default")
    return analysistest.end(env)

exports_bodies_default_test = analysistest.make(_exports_bodies_default_test_impl)

# AdaInfo direct ALI counts match the unit count.
def _direct_ali_counts_test_impl(ctx):
    env = analysistest.begin(ctx)
    target = analysistest.target_under_test(env)
    info = target[AdaInfo]
    asserts.equals(env, 2, len(info.direct_spec_alis.to_list()))
    asserts.equals(env, 2, len(info.direct_body_alis.to_list()))
    asserts.equals(env, 2, len(info.direct_objects.to_list()))
    return analysistest.end(env)

direct_ali_counts_test = analysistest.make(_direct_ali_counts_test_impl)

# Transitive aggregation: a downstream lib sees its own + dep's direct ALIs.
def _copts_propagated_test_impl(ctx):
    env = analysistest.begin(ctx)
    actions = analysistest.target_actions(env)
    interface = [a for a in actions if a.mnemonic == "AdaCompileInterface"]
    full = [a for a in actions if a.mnemonic == "AdaCompileFull"]
    asserts.true(env, len(interface) > 0, "expected at least one interface compile")
    asserts.true(env, len(full) > 0, "expected at least one full compile")
    for action in interface + full:
        asserts.true(env, "-gnatwa" in action.argv,
                     "copts -gnatwa missing in %s argv: %s" % (action.mnemonic, action.argv))
        asserts.true(env, "-O2" in action.argv,
                     "copts -O2 missing in %s argv: %s" % (action.mnemonic, action.argv))
    return analysistest.end(env)

copts_propagated_test = analysistest.make(_copts_propagated_test_impl)

def _config_pragmas_propagated_test_impl(ctx):
    env = analysistest.begin(ctx)
    actions = analysistest.target_actions(env)
    compiles = [a for a in actions if a.mnemonic in ("AdaCompileInterface", "AdaCompileFull")]
    asserts.true(env, len(compiles) > 0, "expected at least one compile action")
    for action in compiles:
        gnatec = [a for a in action.argv if a.startswith("-gnatec=")]
        asserts.equals(env, 1, len(gnatec),
                       "expected one -gnatec= flag in %s argv, got %s" % (action.mnemonic, gnatec))
        asserts.true(env, gnatec[0].endswith("/restrict.adc"),
                     "-gnatec should point at restrict.adc, got: %s" % gnatec[0])
        adc_inputs = [f for f in action.inputs.to_list() if f.path.endswith("/restrict.adc")]
        asserts.equals(env, 1, len(adc_inputs),
                       "restrict.adc must be in inputs of %s" % action.mnemonic)
    return analysistest.end(env)

config_pragmas_propagated_test = analysistest.make(_config_pragmas_propagated_test_impl)

# Explicit subunits attribute: file in subunits should NOT get a standalone compile,
# even when its stem would normally be treated as a body-only main by the heuristic.
def _explicit_subunits_test_impl(ctx):
    env = analysistest.begin(ctx)
    actions = analysistest.target_actions(env)
    full = [a for a in actions if a.mnemonic == "AdaCompileFull"]
    # Only the parent unit should get a full compile, not parent_oddly_named.adb.
    asserts.equals(env, 1, len(full),
                   "expected only the parent's full compile, got %d" % len(full))
    parent_full = full[0]
    asserts.true(env, parent_full.outputs.to_list()[0].path.endswith("parent.ali"),
                 "expected parent.ali, got %s" % parent_full.outputs.to_list()[0].path)
    # The subunit file must appear in the parent compile's input set.
    input_paths = [f.path for f in parent_full.inputs.to_list()]
    asserts.true(env,
                 any([p.endswith("/parent_oddly_named.adb") for p in input_paths]),
                 "explicit subunit must flow as input to parent compile")
    return analysistest.end(env)

explicit_subunits_test = analysistest.make(_explicit_subunits_test_impl)

def _transitive_aggregation_test_impl(ctx):
    env = analysistest.begin(ctx)
    target = analysistest.target_under_test(env)
    info = target[AdaInfo]
    # 1 own unit (foo) + 2 from dep (bar, types_pkg) = 3 spec ALIs total
    # Actually spec_alis includes only body-having units → foo + bar = 2 (types_pkg is spec-only)
    asserts.equals(env, 2, len(info.transitive_spec_alis.to_list()))
    # body_alis includes all 3 (foo, bar, types_pkg)
    asserts.equals(env, 3, len(info.transitive_body_alis.to_list()))
    return analysistest.end(env)

transitive_aggregation_test = analysistest.make(_transitive_aggregation_test_impl)
