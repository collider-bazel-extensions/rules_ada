"""Providers exposed by rules_ada."""

AdaInfo = provider(
    doc = "Carries the spec/body ALI/object/spec closure of an Ada compilation target.",
    fields = {
        "transitive_spec_alis": "depset[File]: spec ALIs reachable through deps (compile inputs)",
        "transitive_body_alis": "depset[File]: body ALIs reachable through deps (binder inputs)",
        "transitive_objects": "depset[File]: body .o files reachable through deps (link inputs)",
        "transitive_specs": "depset[File]: .ads files reachable through deps",
        "transitive_exported_bodies": "depset[File]: .adb sources from libs marked exports_bodies; compile inputs for cross-lib generic instantiation",
        "transitive_srcdirs": "depset[str]: dirs to add via -I for .ads source lookup",
        "transitive_spec_alidirs": "depset[str]: dirs containing spec ALIs",
        "transitive_body_alidirs": "depset[str]: dirs containing body ALIs",
        "direct_spec_alis": "depset[File]: spec ALIs emitted by this target only",
        "direct_body_alis": "depset[File]: body ALIs emitted by this target only",
        "direct_objects": "depset[File]: body .o files emitted by this target only",
        "units": "list[struct(stem, spec, body, spec_ali, body_ali, object)]",
    },
)

def merge_ada_infos(deps):
    """Combine AdaInfo from deps into an aggregate view used by action helpers."""
    return struct(
        transitive_spec_alis = depset(transitive = [d[AdaInfo].transitive_spec_alis for d in deps]),
        transitive_body_alis = depset(transitive = [d[AdaInfo].transitive_body_alis for d in deps]),
        transitive_objects = depset(transitive = [d[AdaInfo].transitive_objects for d in deps]),
        transitive_specs = depset(transitive = [d[AdaInfo].transitive_specs for d in deps]),
        transitive_exported_bodies = depset(transitive = [d[AdaInfo].transitive_exported_bodies for d in deps]),
        transitive_srcdirs = depset(transitive = [d[AdaInfo].transitive_srcdirs for d in deps]),
        transitive_spec_alidirs = depset(transitive = [d[AdaInfo].transitive_spec_alidirs for d in deps]),
        transitive_body_alidirs = depset(transitive = [d[AdaInfo].transitive_body_alidirs for d in deps]),
    )
