"""Analysis tests for ada_static_library."""

load("@bazel_skylib//lib:unittest.bzl", "analysistest", "asserts")
load("@rules_cc//cc/common:cc_info.bzl", "CcInfo")

def _action_counts(actions, mnemonic):
    return [a for a in actions if a.mnemonic == mnemonic]

# Action graph: PIC unit compiles + library-mode bind + binder compile + AdaArchive (no link).
def _static_action_graph_test_impl(ctx):
    env = analysistest.begin(ctx)
    actions = analysistest.target_actions(env)
    asserts.equals(env, 0, len(_action_counts(actions, "AdaCompileInterface")))
    asserts.equals(env, 2, len(_action_counts(actions, "AdaCompileFull")),
                   "expected unit body + binder body compiles")
    asserts.equals(env, 1, len(_action_counts(actions, "AdaBind")))
    asserts.equals(env, 1, len(_action_counts(actions, "AdaArchive")))
    asserts.equals(env, 0, len(_action_counts(actions, "AdaLinkShared")),
                   "static library must not run AdaLinkShared")
    asserts.equals(env, 0, len(_action_counts(actions, "AdaLink")))
    return analysistest.end(env)

static_action_graph_test = analysistest.make(_static_action_graph_test_impl)

# Compiles must include -fPIC so the .a can be linked into either binaries or .so consumers.
def _static_compiles_are_pic_test_impl(ctx):
    env = analysistest.begin(ctx)
    for a in _action_counts(analysistest.target_actions(env), "AdaCompileFull"):
        asserts.true(env, "-fPIC" in a.argv,
                     "expected -fPIC in compile argv: %s" % a.argv)
    return analysistest.end(env)

static_compiles_are_pic_test = analysistest.make(_static_compiles_are_pic_test_impl)

# Bind action must be in library mode for static libs too (auto-init via constructors).
def _static_bind_is_library_mode_test_impl(ctx):
    env = analysistest.begin(ctx)
    bind_actions = _action_counts(analysistest.target_actions(env), "AdaBind")
    asserts.equals(env, 1, len(bind_actions))
    argv = bind_actions[0].argv
    asserts.true(env, "-n" in argv, "missing -n")
    asserts.true(env, "-a" in argv, "missing -a")
    return analysistest.end(env)

static_bind_is_library_mode_test = analysistest.make(_static_bind_is_library_mode_test_impl)

# Archive action runs `ar rcs <output> <objects>` and must include the binder object.
def _archive_includes_binder_test_impl(ctx):
    env = analysistest.begin(ctx)
    arch = _action_counts(analysistest.target_actions(env), "AdaArchive")
    asserts.equals(env, 1, len(arch))
    inputs = [f.path for f in arch[0].inputs.to_list()]
    binder_objs = [p for p in inputs if "/b__" in p and p.endswith(".o")]
    asserts.true(env, len(binder_objs) > 0,
                 "binder object must be archived alongside unit objects")
    return analysistest.end(env)

archive_includes_binder_test = analysistest.make(_archive_includes_binder_test_impl)

# CcInfo must expose a static (PIC) library to link.
def _static_exposes_cc_info_test_impl(ctx):
    env = analysistest.begin(ctx)
    target = analysistest.target_under_test(env)
    asserts.true(env, CcInfo in target, "ada_static_library must provide CcInfo")
    libs = []
    for li in target[CcInfo].linking_context.linker_inputs.to_list():
        for lib in li.libraries:
            if lib.pic_static_library != None:
                libs.append(lib.pic_static_library)
    asserts.equals(env, 1, len(libs),
                   "CcInfo should expose one pic_static_library, got %d" % len(libs))
    asserts.true(env, libs[0].path.endswith(".a"),
                 "expected .a suffix, got: %s" % libs[0].path)
    return analysistest.end(env)

static_exposes_cc_info_test = analysistest.make(_static_exposes_cc_info_test_impl)
