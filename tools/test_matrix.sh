#!/usr/bin/env bash
# Run the full rules_ada test suite under each registered toolchain.
# Exits nonzero if any configuration fails.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

declare -a CONFIGS=(
  "fsf_gnat:default"
  "system_gnat:--extra_toolchains=@system_gnat//:toolchain"
)

failed=()
for cfg in "${CONFIGS[@]}"; do
  name="${cfg%%:*}"
  args="${cfg#*:}"
  [ "$args" = "default" ] && args=""

  echo
  echo "=================================================================="
  echo "  running test suite under: $name"
  echo "=================================================================="
  if bazel test //... $args; then
    echo "  $name: PASS"
  else
    echo "  $name: FAIL"
    failed+=("$name")
  fi
done

echo
if [ "${#failed[@]}" -eq 0 ]; then
  echo "matrix: all configurations passed"
  exit 0
else
  echo "matrix: failures in: ${failed[*]}"
  exit 1
fi
