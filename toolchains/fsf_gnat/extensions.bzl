"""Module extension for the hermetic FSF GNAT toolchain."""

load(":repo.bzl", "fsf_gnat_repo")

def _fsf_gnat_impl(_module_ctx):
    fsf_gnat_repo(name = "fsf_gnat")

fsf_gnat = module_extension(implementation = _fsf_gnat_impl)
