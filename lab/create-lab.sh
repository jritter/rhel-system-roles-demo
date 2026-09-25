#!/usr/bin/env bash
# Create all 3 RHEL 9 lab VMs (node01, node02, node03).
# Usage: ./lab/create-lab.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "${SCRIPT_DIR}/common.sh"

echo "========================================"
echo "  Creating rhel-system-roles demo lab"
echo "  VMs: ${LAB_VMS[*]}"
echo "========================================"
echo

for vm in "${LAB_VMS[@]}"; do
  echo "--- ${vm} ---"
  "${SCRIPT_DIR}/create-vm.sh" "${vm}"
  echo
done

echo "==> Refreshing Ansible inventory"
generate_inventory

echo
echo "========================================"
echo "  Lab is ready!"
echo "  Run:  ansible -i inventory/hosts all -m ping"
echo "========================================"
