"""Module extension that materializes a hermetic-ish view of the system GNAT install."""

load(":repo.bzl", "system_gnat_repo")

def _system_gnat_impl(_module_ctx):
    system_gnat_repo(name = "system_gnat")

system_gnat = module_extension(implementation = _system_gnat_impl)
