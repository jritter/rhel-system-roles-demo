# RHEL System Roles Demo

A demo project that uses [RHEL System Roles](https://access.redhat.com/articles/3050101) to build a standard operating environment across a fleet of RHEL 9 machines.

## Lab Setup

The `lab/` directory contains scripts to create 3 RHEL 9 VMs using libvirt:

| VM | Ansible Group | Purpose |
|---|---|---|
| `node01` | `web` | Web server |
| `node02` | `web` | Web server |
| `node03` | `db` | Database server |

```bash
# Create all 3 VMs
./lab/create-lab.sh

# Verify connectivity
ansible all -m ping

# Tear down
./lab/destroy-lab.sh
```

See [`lab/config.env.example`](lab/config.env.example) for configurable options (image path, VM sizing, timezone, credentials).

## Playbooks

| Playbook | Description |
|---|---|
| `baseconfig.yml` | Apply baseline configuration to all hosts (timezone, login banner, sshd, firewall, cockpit, tlog, AIDE, crypto policies, SELinux, kdump) |
| `database.yml` | Deploy PostgreSQL on the `db` group |
| `ping.yml` | Connectivity check |

```bash
# Apply the full baseline
ansible-playbook baseconfig.yml

# Deploy the database
ansible-playbook database.yml
```

## Resources

### Videos

- [Management with System Roles — Into the Terminal 79](https://www.youtube.com/watch?v=RzdjJLb7i_M)
- [Automation with System Roles — Into the Terminal 80](https://www.youtube.com/watch?v=5_EvmnbF8tA)

### Blog Posts

- [Introduction to RHEL System Roles](https://www.redhat.com/en/blog/introduction-rhel-system-roles)
- [Automating Firewall Configuration with RHEL System Roles](https://www.redhat.com/en/blog/automating-firewall-configuration-rhel-system-roles)

### Interactive Labs

- [Configure Firewalls with RHEL System Roles](https://zero.rhdp.net/lab/zt-rhelbu.zt-firewall-system-role.prod) (10–15 minutes)
- [Build a Standard Operating Environment with RHEL System Roles](https://zero.rhdp.net/lab/zt-rhelbu.zt-rhel-system-roles.prod) (10–20 minutes)

### Reference

- [Available RHEL System Roles](https://access.redhat.com/articles/3050101)
