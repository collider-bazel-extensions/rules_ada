"""Module extension for the ada-toml smoke test repo."""

load(":repo.bzl", "ada_toml_repo")

def _impl(_module_ctx):
    ada_toml_repo(name = "ada_toml")

ada_toml = module_extension(implementation = _impl)
