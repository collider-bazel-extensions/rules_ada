"""Module extension for the AdaSAT smoke test repo."""

load(":repo.bzl", "adasat_repo")

def _impl(_module_ctx):
    adasat_repo(name = "adasat")

adasat = module_extension(implementation = _impl)
