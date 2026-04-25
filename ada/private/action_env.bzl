"""Shared env/sandbox kwargs derived from the toolchain."""

def action_env_kwargs(toolchain):
    if toolchain.use_host_env:
        return {"use_default_shell_env": True}
    return {"env": {"PATH": toolchain.bin_dir}}
