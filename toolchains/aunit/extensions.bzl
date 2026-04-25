"""Module extension for the AUnit testing framework."""

load(":repo.bzl", "aunit_repo")

def _impl(_module_ctx):
    aunit_repo(name = "aunit")

aunit = module_extension(implementation = _impl)
