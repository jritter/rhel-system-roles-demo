#!/usr/bin/env bash
# Create a RHEL 9 lab guest for the rhel-system-roles demo.
# Usage: ./lab/create-vm.sh <node01|node02|node03>
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "${SCRIPT_DIR}/common.sh"

NAME="${1:-}"
[[ -n "${NAME}" ]] || die "usage: $0 <${LAB_VMS[*]// /|}>"

validate_vm_name "${NAME}"

BASE_IMAGE="$(readlink -f "${RHEL9_IMAGE}")"
DISK="${DISKS_DIR}/${NAME}.qcow2"
CIDATA_ISO="${CLOUD_INIT_DIR}/${NAME}-cidata.iso"

require_cmd virsh
require_cmd virt-install
require_cmd qemu-img

[[ -f "${BASE_IMAGE}" ]] || die "base image not found: ${BASE_IMAGE}
Download the RHEL 9 KVM guest qcow2 from the Red Hat Customer Portal and place it at that path
(or set RHEL9_IMAGE in lab/config.env)."

if virsh --connect "${LIBVIRT_URI}" dominfo "${NAME}" >/dev/null 2>&1; then
  die "domain '${NAME}' already exists; run lab/destroy-vm.sh ${NAME} first"
fi

echo "==> Creating backing disk ${DISK} (${VM_DISK_GIB}G) from ${BASE_IMAGE}"
qemu-img create -f qcow2 -F qcow2 -b "${BASE_IMAGE}" "${DISK}" >/dev/null
qemu-img resize "${DISK}" "${VM_DISK_GIB}G" >/dev/null

echo "==> Building cloud-init ISO ${CIDATA_ISO}"
build_cloudinit_iso "${NAME}" "${CIDATA_ISO}"

echo "==> Importing domain ${NAME} via virt-install"
virt-install \
  --connect "${LIBVIRT_URI}" \
  --name "${NAME}" \
  --memory "${VM_MEMORY_MIB}" \
  --vcpus "${VM_VCPUS}" \
  --cpu host-passthrough \
  --os-variant rhel9-unknown \
  --disk "path=${DISK},format=qcow2,bus=virtio" \
  --disk "path=${CIDATA_ISO},device=cdrom" \
  --network "network=${LIBVIRT_NETWORK},model=virtio" \
  --graphics none \
  --console pty,target_type=serial \
  --import \
  --noautoconsole \
  --wait 0

echo "==> Waiting for cloud-init / SSH on ${NAME}"
"${SCRIPT_DIR}/wait-ssh.sh" "${NAME}"

echo "==> Refreshing Ansible inventory"
generate_inventory

IP="$(guest_ipv4 "${NAME}")"
echo
echo "Guest ${NAME} is ready (ansible_user=${VM_USER}, ansible_host=${IP})."
