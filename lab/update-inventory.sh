#!/usr/bin/env bash
# Re-render inventory/hosts with IP addresses from libvirt DHCP leases.
# Usage: ./lab/update-inventory.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "${SCRIPT_DIR}/common.sh"

generate_inventory
