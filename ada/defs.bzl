"""Public API for rules_ada."""

load("//ada/private:ada_binary.bzl", _ada_binary = "ada_binary")
load("//ada/private:ada_library.bzl", _ada_library = "ada_library")
load("//ada/private:ada_shared_library.bzl", _ada_shared_library = "ada_shared_library")
load("//ada/private:ada_static_library.bzl", _ada_static_library = "ada_static_library")
load("//ada/private:ada_test.bzl", _ada_test = "ada_test")

ada_library = _ada_library
ada_binary = _ada_binary
ada_test = _ada_test
ada_shared_library = _ada_shared_library
ada_static_library = _ada_static_library
