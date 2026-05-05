# Episode 4: NFS Storage and FreeIPA

Configuration files for [Episode 4 of HPC From Scratch](https://theloginnode.com/posts/2026/05/hpc_from_scratch_04/). The blog post covers what each piece does and why. This directory is the source of the playbooks.

## Files

| File | Purpose |
|------|---------|
| [`hosts.ini`](hosts.ini) | Ansible inventory for all 6 nodes |
| [`ansible.cfg`](ansible.cfg) | Ansible configuration (paths relative to `/opt/ansible`) |
| [`vault.yaml.example`](vault.yaml.example) | Secret variables template — copy to `vault.yaml` and encrypt |
| [`playbooks/nvme_setup_management.yaml`](playbooks/nvme_setup_management.yaml) | LVM partitioning on NVMe drive (arbiter) |
| [`playbooks/nfs_setup.yaml`](playbooks/nfs_setup.yaml) | NFS server on arbiter, clients on all nodes, XFS quota |
| [`playbooks/chrony_setup.yaml`](playbooks/chrony_setup.yaml) | NTP server on carrier, clients on all other nodes |
| [`playbooks/freeipa_setup.yaml`](playbooks/freeipa_setup.yaml) | FreeIPA server on arbiter, arbiter entry in /etc/hosts on all nodes, client enrollment |
| [`scripts/user_creation.sh`](scripts/user_creation.sh) | Add a new HPC user with home directory, quota, and Slurm accounting |

## Setup

> **Warning:** These playbooks are designed for fresh installations. Re-running `nvme_setup_management.yaml` on an existing system will erase all data on the NVMe drive. Re-running `freeipa_setup.yaml` with `--force-join` will overwrite existing client enrollments. Run each playbook once during initial setup only.

**1. Install Ansible on arbiter**

```bash
sudo dnf install ansible-core
sudo mkdir -p /opt/ansible
sudo chown wpaik:wpaik /opt/ansible
```

Copy this directory to `/opt/ansible`.

**2. SSH key**

Generate on arbiter and distribute to all nodes:

```bash
ssh-keygen -t ed25519 -f /opt/ansible/.ssh/worker_ed25519 -N ""
ssh-copy-id -i /opt/ansible/.ssh/worker_ed25519.pub wpaik@192.168.50.1    # carrier
ssh-copy-id -i /opt/ansible/.ssh/worker_ed25519.pub wpaik@192.168.50.15   # interceptor-01
ssh-copy-id -i /opt/ansible/.ssh/worker_ed25519.pub wpaik@192.168.50.32   # interceptor-02
ssh-copy-id -i /opt/ansible/.ssh/worker_ed25519.pub wpaik@192.168.50.11   # corsair-01
ssh-copy-id -i /opt/ansible/.ssh/worker_ed25519.pub wpaik@192.168.50.19   # observer
```

**3. Vault**

```bash
cp vault.yaml.example vault.yaml
# fill in vault.yaml with your passwords
ansible-vault encrypt vault.yaml
echo "your_vault_password" > /opt/ansible/.ansible_vault_pw
chmod 600 /opt/ansible/.ansible_vault_pw
```

**4. Verify connectivity**

```bash
cd /opt/ansible
ansible all -m ping
```

**5. Run playbooks in order**

```bash
ansible-playbook playbooks/nvme_setup_management.yaml
ansible-playbook playbooks/nfs_setup.yaml -K
ansible-playbook playbooks/chrony_setup.yaml -K
ansible-playbook playbooks/freeipa_setup.yaml -K
```

> **Note:** After `nfs_setup.yaml` completes, manually reboot carrier before running the next playbook. Kerberos (used by FreeIPA) is sensitive to time drift, so `chrony_setup.yaml` must run before `freeipa_setup.yaml`.

## Adding a New User

Run on arbiter after setup is complete:

```bash
kinit admin
bash scripts/user_creation.sh
```

## Troubleshooting

**NFS mount hangs on boot**

`_netdev` in fstab tells the node to wait for network before mounting. If a node boots before arbiter is ready, mount manually:

```bash
sudo mount -a
```

**FreeIPA enrollment fails with DNS error**

The playbook adds `arbiter.cluster.local` to `/etc/hosts` before enrollment. If enrollment still fails, verify the entry exists on the failing node:

```bash
getent hosts arbiter.cluster.local    # should return 192.168.50.50
```

If missing, add it manually and retry:

```bash
echo "192.168.50.50 arbiter.cluster.local arbiter" | sudo tee -a /etc/hosts
```

**Home directory not created on first SSH login**

```bash
sudo systemctl enable --now oddjobd
```

**NFS permission errors after FreeIPA enrollment**

Check nsswitch.conf — `files` must appear before `sss`:

```bash
grep -E "^(passwd|group)" /etc/nsswitch.conf
```

If SELinux is blocking NFS home directories:

```bash
sudo setsebool -P use_nfs_home_dirs 1
```

**Node freezes on boot after NFS setup**

Stale `resume=UUID` in GRUB can cause boot hangs. From the GRUB menu, press `e`, remove the `resume=UUID=...` argument, then `Ctrl+X` to boot. Once up:

```bash
grubby --update-kernel=ALL --remove-args="resume=UUID=<UUID>"
```
