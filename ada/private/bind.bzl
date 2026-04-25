"""gnatbind helpers — binary mode and library mode."""

load(":action_env.bzl", "action_env_kwargs")

# Shared shell wrapper. gnatbind writes b__name.{ads,adb} into CWD and
# embeds the -o argument into a `pragma Source_File_Name`, so we must
# chdir into the output dir and pass a bare basename. All -aO/-aI dirs
# and any *.ali args get prefixed with $EXEC_ROOT so they resolve from
# the new CWD.
_BIND_SCRIPT = r"""
set -euo pipefail
EXEC_ROOT="$(pwd)"
GNATBIND="$EXEC_ROOT/$1"; shift
OUT_DIR="$EXEC_ROOT/$1"; shift
OUT_NAME="$1"; shift

REWRITTEN=()
for arg in "$@"; do
  case "$arg" in
    -aO/*|-aI/*) REWRITTEN+=("$arg") ;;
    -aO*)        REWRITTEN+=("-aO$EXEC_ROOT/${arg#-aO}") ;;
    -aI*)        REWRITTEN+=("-aI$EXEC_ROOT/${arg#-aI}") ;;
    *.ali)       REWRITTEN+=("$EXEC_ROOT/$arg") ;;
    *)           REWRITTEN+=("$arg") ;;
  esac
done

cd "$OUT_DIR"
exec "$GNATBIND" -o "$OUT_NAME" "${REWRITTEN[@]}"
"""

def _run_bind(ctx, toolchain, deps_view, binder_ads, binder_adb, ali_inputs, extra_flags, progress):
    """Common gnatbind invocation. ali_inputs is the list of File ALIs that
    appear as positional args (the closure roots gnatbind walks)."""
    args = ctx.actions.args()
    args.add(toolchain.gnatbind.path)
    args.add(binder_adb.dirname)
    args.add(binder_adb.basename)
    args.add_all(extra_flags)
    args.add_all(ali_inputs)
    args.add_all(deps_view.transitive_body_alidirs, format_each = "-aO%s")
    args.add_all(deps_view.transitive_srcdirs, format_each = "-aI%s")
    args.add("-aO" + toolchain.runtime_alidir)
    args.add("-aI" + toolchain.runtime_specdir)

    ctx.actions.run_shell(
        command = _BIND_SCRIPT,
        arguments = [args],
        inputs = depset(
            direct = list(ali_inputs) + [toolchain.gnatbind],
            transitive = [
                deps_view.transitive_body_alis,
                deps_view.transitive_specs,
                toolchain.runtime_specs,
                toolchain.all_files,
            ],
        ),
        outputs = [binder_ads, binder_adb],
        mnemonic = "AdaBind",
        progress_message = progress,
        **action_env_kwargs(toolchain)
    )

def bind(ctx, toolchain, deps_view, main_ali, main_stem, out_subdir = None):
    """Binary-mode bind: one main_ali becomes a runnable executable's binder."""
    if out_subdir == None:
        out_subdir = "_ada/%s" % ctx.label.name
    binder_ads = ctx.actions.declare_file("%s/b__%s.ads" % (out_subdir, main_stem))
    binder_adb = ctx.actions.declare_file("%s/b__%s.adb" % (out_subdir, main_stem))
    _run_bind(
        ctx, toolchain, deps_view,
        binder_ads = binder_ads,
        binder_adb = binder_adb,
        ali_inputs = [main_ali],
        extra_flags = [],
        progress = "Binding Ada main %s" % main_stem,
    )
    return binder_ads, binder_adb

def bind_library(ctx, toolchain, deps_view, unit_alis, lib_name, out_subdir = None):
    """Library-mode bind: emits init/final entry points for a shared library.
    `gnatbind -n -a -Llib_name unit1.ali unit2.ali ...` produces a binder body
    whose elaboration is auto-invoked on .so load via Linker_Constructor."""
    if out_subdir == None:
        out_subdir = "_ada/%s" % ctx.label.name
    binder_ads = ctx.actions.declare_file("%s/b__%s.ads" % (out_subdir, lib_name))
    binder_adb = ctx.actions.declare_file("%s/b__%s.adb" % (out_subdir, lib_name))
    _run_bind(
        ctx, toolchain, deps_view,
        binder_ads = binder_ads,
        binder_adb = binder_adb,
        ali_inputs = unit_alis,
        extra_flags = ["-n", "-a", "-L" + lib_name],
        progress = "Binding Ada shared library %s" % lib_name,
    )
    return binder_ads, binder_adb
