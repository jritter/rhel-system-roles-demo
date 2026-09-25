#!/usr/bin/env bash
# Shared helpers for rhel-system-roles-demo lab scripts.
set -euo pipefail

LAB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${LAB_DIR}/.." && pwd)"

# Load optional local config and repo .env (RHSM credentials)
if [[ -f "${LAB_DIR}/config.env" ]]; then
  # shellcheck source=/dev/null
  source "${LAB_DIR}/config.env"
elif [[ -f "${LAB_DIR}/config.env.example" ]]; then
  # shellcheck source=/dev/null
  source "${LAB_DIR}/config.env.example"
fi

if [[ -f "${REPO_ROOT}/.env" ]]; then
  set -a
  # shellcheck source=/dev/null
  source "${REPO_ROOT}/.env"
  set +a
fi

LIBVIRT_URI="${LIBVIRT_URI:-qemu:///system}"
LIBVIRT_NETWORK="${LIBVIRT_NETWORK:-default}"
IMAGES_DIR="${IMAGES_DIR:-${LAB_DIR}/images}"
DISKS_DIR="${DISKS_DIR:-${LAB_DIR}/disks}"
CLOUD_INIT_DIR="${CLOUD_INIT_DIR:-${LAB_DIR}/cloud-init/generated}"
RHEL9_IMAGE="${RHEL9_IMAGE:-${IMAGES_DIR}/rhel-9.8-x86_64-kvm.qcow2}"
VM_VCPUS="${VM_VCPUS:-2}"
VM_MEMORY_MIB="${VM_MEMORY_MIB:-2048}"
VM_DISK_GIB="${VM_DISK_GIB:-20}"
VM_USER="${VM_USER:-rhel}"
VM_PASSWORD="${VM_PASSWORD:-redhat}"
VM_TIMEZONE="${VM_TIMEZONE:-Europe/Amsterdam}"

# The VMs that make up the lab and their Ansible group assignments
LAB_VMS=("node01" "node02" "node03")
declare -A VM_GROUPS=(
  [node01]="web"
  [node02]="web"
  [node03]="db"
)

mkdir -p "${IMAGES_DIR}" "${DISKS_DIR}" "${CLOUD_INIT_DIR}"

die() {
  echo "ERROR: $*" >&2
  exit 1
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "required command not found: $1"
}

resolve_ssh_pubkey() {
  if [[ -n "${SSH_PUBKEY:-}" ]]; then
    printf '%s\n' "${SSH_PUBKEY}"
    return
  fi
  if [[ -n "${SSH_PUBKEY_FILE:-}" && -f "${SSH_PUBKEY_FILE}" ]]; then
    cat "${SSH_PUBKEY_FILE}"
    return
  fi
  for candidate in "${HOME}/.ssh/id_ed25519.pub" "${HOME}/.ssh/id_rsa.pub"; do
    if [[ -f "${candidate}" ]]; then
      cat "${candidate}"
      return
    fi
  done
  die "no SSH public key found; set SSH_PUBKEY or SSH_PUBKEY_FILE"
}

validate_vm_name() {
  local name="$1"
  local valid=false
  for vm in "${LAB_VMS[@]}"; do
    if [[ "${vm}" == "${name}" ]]; then
      valid=true
      break
    fi
  done
  "${valid}" || die "unknown VM '${name}' (expected one of: ${LAB_VMS[*]})"
}

guest_ipv4() {
  local name="$1"
  local ip=""
  ip="$(virsh --connect "${LIBVIRT_URI}" domifaddr "${name}" --source lease 2>/dev/null \
    | awk '/ipv4/ {print $4}' | head -n1 | cut -d/ -f1 || true)"
  if [[ -z "${ip}" ]]; then
    ip="$(virsh --connect "${LIBVIRT_URI}" domifaddr "${name}" 2>/dev/null \
      | awk '/ipv4/ {print $4}' | head -n1 | cut -d/ -f1 || true)"
  fi
  printf '%s' "${ip}"
}

build_cloudinit_iso() {
  local name="$1"
  local out_iso="$2"
  local ssh_pubkey instance_id workdir

  require_cmd sed

  ssh_pubkey="$(resolve_ssh_pubkey | tr -d '\r')"
  instance_id="$(date +%s)"
  workdir="$(mktemp -d)"

  local esc_pubkey esc_password
  esc_pubkey="$(printf '%s' "${ssh_pubkey}" | sed -e 's/[&\\]/\\&/g')"
  esc_password="$(printf '%s' "${VM_PASSWORD}" | sed -e 's/[&\\]/\\&/g')"

  # Build the rh_subscription block when RHSM credentials are available
  local rh_sub_block=""
  if [[ -n "${RHSM_ORG:-}" && -n "${RHSM_ACTIVATIONKEY:-}" ]]; then
    local esc_org esc_key
    esc_org="$(printf '%s' "${RHSM_ORG}" | sed -e 's/[&\\]/\\&/g')"
    esc_key="$(printf '%s' "${RHSM_ACTIVATIONKEY}" | sed -e 's/[&\\]/\\&/g')"
    rh_sub_block="rh_subscription:\\
  activation-key: ${esc_key}\\
  org: ${esc_org}\\
  auto-attach: true"
  fi

  sed \
    -e "s|__HOSTNAME__|${name}|g" \
    -e "s|__VM_USER__|${VM_USER}|g" \
    -e "s|__VM_PASSWORD__|${esc_password}|g" \
    -e "s|__SSH_PUBKEY__|${esc_pubkey}|g" \
    -e "s|__VM_TIMEZONE__|${VM_TIMEZONE}|g" \
    -e "s|__RH_SUBSCRIPTION_BLOCK__|${rh_sub_block}|g" \
    "${LAB_DIR}/cloud-init/user-data.yaml.in" > "${workdir}/user-data"

  sed \
    -e "s|__HOSTNAME__|${name}|g" \
    -e "s|__INSTANCE_ID__|${instance_id}|g" \
    "${LAB_DIR}/cloud-init/meta-data.yaml.in" > "${workdir}/meta-data"

  if command -v cloud-localds >/dev/null 2>&1; then
    cloud-localds "${out_iso}" "${workdir}/user-data" "${workdir}/meta-data"
  elif command -v genisoimage >/dev/null 2>&1; then
    genisoimage -output "${out_iso}" -volid cidata -joliet -rock \
      "${workdir}/user-data" "${workdir}/meta-data" >/dev/null
  elif command -v mkisofs >/dev/null 2>&1; then
    mkisofs -output "${out_iso}" -volid cidata -joliet -rock \
      "${workdir}/user-data" "${workdir}/meta-data" >/dev/null
  elif command -v xorriso >/dev/null 2>&1; then
    xorriso -as mkisofs -o "${out_iso}" -V cidata -J -R \
      "${workdir}/user-data" "${workdir}/meta-data" >/dev/null
  else
    rm -rf "${workdir}"
    die "need cloud-localds, genisoimage, mkisofs, or xorriso to build cloud-init ISO"
  fi

  cp "${workdir}/user-data" "${CLOUD_INIT_DIR}/${name}-user-data"
  cp "${workdir}/meta-data" "${CLOUD_INIT_DIR}/${name}-meta-data"
  rm -rf "${workdir}"
}

generate_inventory() {
  local inv_file="${REPO_ROOT}/inventory/hosts"
  local -A groups

  # Collect IPs for running VMs and organise by group
  for vm in "${LAB_VMS[@]}"; do
    if virsh --connect "${LIBVIRT_URI}" dominfo "${vm}" >/dev/null 2>&1; then
      local ip
      ip="$(guest_ipv4 "${vm}")"
      if [[ -n "${ip}" ]]; then
        local grp="${VM_GROUPS[${vm}]}"
        groups[${grp}]+="${vm} ansible_host=${ip}"$'\n'
      fi
    fi
  done

  # Build the inventory file
  {
    # Collect unique group names
    local -a seen_groups=()
    for vm in "${LAB_VMS[@]}"; do
      local grp="${VM_GROUPS[${vm}]}"
      local already=false
      for s in "${seen_groups[@]+"${seen_groups[@]}"}"; do
        [[ "${s}" == "${grp}" ]] && already=true && break
      done
      if ! "${already}"; then
        seen_groups+=("${grp}")
      fi
    done

    for grp in "${seen_groups[@]}"; do
      echo "[${grp}]"
      if [[ -n "${groups[${grp}]:-}" ]]; then
        printf '%s' "${groups[${grp}]}"
      fi
      echo
    done

    cat <<EOF
[all:vars]
ansible_user=${VM_USER}
ansible_password=${VM_PASSWORD}
ansible_ssh_common_args='-o StrictHostKeyChecking=no'
EOF
  } > "${inv_file}"

  echo "Inventory written to ${inv_file}"
}
