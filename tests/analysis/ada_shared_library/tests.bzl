"""Analysis tests for ada_shared_library."""

load("@bazel_skylib//lib:unittest.bzl", "analysistest", "asserts")
load("@rules_cc//cc/common:cc_info.bzl", "CcInfo")

def _action_counts(actions, mnemonic):
    return [a for a in actions if a.mnemonic == mnemonic]

# Action graph: per-unit AdaCompileFull (PIC) + AdaBind + binder AdaCompileFull + AdaLinkShared.
def _shared_action_graph_test_impl(ctx):
    env = analysistest.begin(ctx)
    actions = analysistest.target_actions(env)
    asserts.equals(env, 0, len(_action_counts(actions, "AdaCompileInterface")),
                   "shared library should not run interface compiles")
    asserts.equals(env, 2, len(_action_counts(actions, "AdaCompileFull")),
                   "expected 1 unit body compile + 1 binder body compile")
    asserts.equals(env, 1, len(_action_counts(actions, "AdaBind")))
    asserts.equals(env, 1, len(_action_counts(actions, "AdaLinkShared")))
    return analysistest.end(env)

shared_action_graph_test = analysistest.make(_shared_action_graph_test_impl)

# Every compile must include -fPIC.
def _shared_compiles_are_pic_test_impl(ctx):
    env = analysistest.begin(ctx)
    actions = analysistest.target_actions(env)
    compiles = _action_counts(actions, "AdaCompileFull")
    for a in compiles:
        asserts.true(env, "-fPIC" in a.argv,
                     "expected -fPIC in compile argv: %s" % a.argv)
    return analysistest.end(env)

shared_compiles_are_pic_test = analysistest.make(_shared_compiles_are_pic_test_impl)

# Bind action must be in library mode (`-n -a -L<name>`).
def _bind_is_library_mode_test_impl(ctx):
    env = analysistest.begin(ctx)
    actions = analysistest.target_actions(env)
    bind_actions = _action_counts(actions, "AdaBind")
    asserts.equals(env, 1, len(bind_actions))
    argv = bind_actions[0].argv
    asserts.true(env, "-n" in argv, "missing -n in gnatbind argv: %s" % argv)
    asserts.true(env, "-a" in argv, "missing -a in gnatbind argv: %s" % argv)
    has_l_name = any([a.startswith("-L") and not a.startswith("-Lib") for a in argv])
    asserts.true(env, has_l_name, "missing -L<name> in gnatbind argv: %s" % argv)
    return analysistest.end(env)

bind_is_library_mode_test = analysistest.make(_bind_is_library_mode_test_impl)

# Link action must use -shared and -Wl,-soname,...
def _link_uses_shared_flags_test_impl(ctx):
    env = analysistest.begin(ctx)
    actions = analysistest.target_actions(env)
    link = _action_counts(actions, "AdaLinkShared")
    asserts.equals(env, 1, len(link))
    argv = link[0].argv
    asserts.true(env, "-shared" in argv, "missing -shared")
    soname_args = [a for a in argv if a.startswith("-Wl,-soname,")]
    asserts.equals(env, 1, len(soname_args), "expected exactly one -Wl,-soname,...")
    return analysistest.end(env)

link_uses_shared_flags_test = analysistest.make(_link_uses_shared_flags_test_impl)

# CcInfo must be present and contain a dynamic library to link.
def _exposes_cc_info_test_impl(ctx):
    env = analysistest.begin(ctx)
    target = analysistest.target_under_test(env)
    asserts.true(env, CcInfo in target, "ada_shared_library must provide CcInfo")
    cc_info = target[CcInfo]
    linker_inputs = cc_info.linking_context.linker_inputs.to_list()
    libs = []
    for li in linker_inputs:
        for lib in li.libraries:
            if lib.dynamic_library != None:
                libs.append(lib.dynamic_library)
    asserts.equals(env, 1, len(libs),
                   "CcInfo should expose one dynamic library, got %d" % len(libs))
    asserts.true(env, libs[0].path.endswith(".so"),
                 "expected .so suffix, got: %s" % libs[0].path)
    return analysistest.end(env)

exposes_cc_info_test = analysistest.make(_exposes_cc_info_test_impl)
