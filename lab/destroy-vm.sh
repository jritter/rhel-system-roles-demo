#!/usr/bin/env bash
# Destroy a lab guest and remove its disk / cloud-init ISO.
# Usage: ./lab/destroy-vm.sh <node01|node02|node03>
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "${SCRIPT_DIR}/common.sh"

NAME="${1:-}"
[[ -n "${NAME}" ]] || die "usage: $0 <${LAB_VMS[*]// /|}>"

validate_vm_name "${NAME}"

DISK="${DISKS_DIR}/${NAME}.qcow2"
CIDATA_ISO="${CLOUD_INIT_DIR}/${NAME}-cidata.iso"

require_cmd virsh

if virsh --connect "${LIBVIRT_URI}" dominfo "${NAME}" >/dev/null 2>&1; then
  IP="$(guest_ipv4 "${NAME}" || true)"
  if [[ -n "${IP}" ]]; then
    echo "==> Best-effort RHSM unregister on ${NAME} (${IP})"
    ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=5 \
      "${VM_USER}@${IP}" \
      "sudo subscription-manager unregister || true; sudo subscription-manager clean || true" \
      2>/dev/null || true
  fi

  echo "==> Destroying domain ${NAME}"
  virsh --connect "${LIBVIRT_URI}" destroy "${NAME}" >/dev/null 2>&1 || true
  virsh --connect "${LIBVIRT_URI}" undefine "${NAME}" --nvram --remove-all-storage >/dev/null 2>&1 \
    || virsh --connect "${LIBVIRT_URI}" undefine "${NAME}" --remove-all-storage >/dev/null 2>&1 \
    || virsh --connect "${LIBVIRT_URI}" undefine "${NAME}" >/dev/null
else
  echo "==> Domain ${NAME} not defined; cleaning leftover files only"
fi

rm -f "${DISK}" "${CIDATA_ISO}" \
  "${CLOUD_INIT_DIR}/${NAME}-user-data" \
  "${CLOUD_INIT_DIR}/${NAME}-meta-data"

generate_inventory || true
echo "Destroyed ${NAME}."
