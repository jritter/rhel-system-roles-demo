#!/usr/bin/env bash
# Destroy all lab VMs (node01, node02, node03).
# Usage: ./lab/destroy-lab.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "${SCRIPT_DIR}/common.sh"

echo "========================================"
echo "  Destroying rhel-system-roles demo lab"
echo "  VMs: ${LAB_VMS[*]}"
echo "========================================"
echo

for vm in "${LAB_VMS[@]}"; do
  echo "--- ${vm} ---"
  "${SCRIPT_DIR}/destroy-vm.sh" "${vm}"
  echo
done

echo
echo "All lab VMs destroyed."
