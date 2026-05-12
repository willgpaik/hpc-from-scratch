# Episode 5: Slurm - Installing the Job Scheduler

Configuration files and Ansible playbooks for [Episode 5 of HPC From Scratch](https://theloginnode.com/posts/2026/05/hpc_from_scratch_05/). The blog post covers what each piece does and why. This directory is the source of the playbooks.

## Files

| File | Purpose |
|------|---------|
| [`configs/slurm.conf`](configs/slurm.conf) | Main Slurm configuration (distribute to all nodes) |
| [`configs/cgroup.conf`](configs/cgroup.conf) | Cgroup v2 configuration for job resource enforcement |
| [`configs/slurmdbd.conf`](configs/slurmdbd.conf) | Slurm database daemon configuration template |
| [`playbooks/01_munge_setup.yaml`](playbooks/01_munge_setup.yaml) | Install Munge, generate shared key, distribute to all nodes |
| [`playbooks/02_slurm_build.yaml`](playbooks/02_slurm_build.yaml) | Create slurm user with fixed UID, build Slurm RPMs from source, pin version in dnf |
| [`playbooks/03_slurm_install.yaml`](playbooks/03_slurm_install.yaml) | Distribute and install RPMs by node role, disable swap on compute nodes |
| [`playbooks/04_slurm_config.yaml`](playbooks/04_slurm_config.yaml) | Configure slurm.conf, set up MariaDB, start all services |
| [`playbooks/fix/04_fix_slurmdb.yaml`](playbooks/fix/04_fix_slurmdb.yaml) | Fix slurmdbd connection issues |
| [`playbooks/fix/05_wakeup_nodes.yaml`](playbooks/fix/05_wakeup_nodes.yaml) | Restart and resume nodes stuck in down/drain state |
| [`playbooks/fix/06_fix_cg_state.yaml`](playbooks/fix/06_fix_cg_state.yaml) | Fix nodes stuck in CG (completing) state |
| [`playbooks/fix/07_slurm_hard_reset.yaml`](playbooks/fix/07_slurm_hard_reset.yaml) | Full cluster reset (wipes all running jobs) |
| [`playbooks/fix/08_sync_slurm_uid.yaml`](playbooks/fix/08_sync_slurm_uid.yaml) | Sync Slurm UID/GID across nodes when Munge auth fails |

## Before You Start

**1. Set RealMemory values**

Run `free -m` on each compute node and use the `total` column value in `configs/slurm.conf`. Do not use the installed RAM amount. The iGPU on M715q nodes reserves memory, and the reported total varies by BIOS UMA Frame Buffer Size setting.

```bash
ansible workers,gpu -m shell -a "free -m | grep Mem" -b
```

**2. Set database password**

Edit `configs/slurmdbd.conf` and replace `YOUR_DB_PASSWORD_HERE` with a real password. Use the same password in `04_slurm_config.yaml` under `slurm_db_password`.

**3. Install community.mysql collection**

Required for the MariaDB setup tasks:

```bash
ansible-galaxy collection install community.mysql
```

## Setup Order

> **Warning:** Run these playbooks once during initial setup only. `02_slurm_build.yaml` downloads and compiles Slurm from source, which takes 10-20 minutes.

```bash
ansible-playbook playbooks/01_munge_setup.yaml -K
ansible-playbook playbooks/02_slurm_build.yaml -K
ansible-playbook playbooks/03_slurm_install.yaml -K
ansible-playbook playbooks/04_slurm_config.yaml -K
```

After `04_slurm_config.yaml` completes, verify from the login node:

```bash
sinfo
srun hostname
```

## Adding Users to Slurm Accounting

After setup, add users to the accounting database so `seff` and `sacct` work correctly:

```bash
sacctmgr -i add user <username> Account=root
```

## Troubleshooting

**Nodes stuck in down or drain state**

```bash
scontrol update NodeName=ALL State=RESUME
# If they keep going back to down, check the log:
ssh interceptor-01 "sudo tail -50 /var/log/slurm/slurmd.log"
# Then run:
ansible-playbook playbooks/fix/05_wakeup_nodes.yaml -K
```

**Munge security violation / jobs hang**

Check that all nodes have the same slurm UID:

```bash
ansible all_nodes -m shell -a "id slurm" -b
```

If UIDs differ, run `fix/08_sync_slurm_uid.yaml`. If the target UID is already occupied by another system user on a node, reassign that user first:

```bash
# Find who owns the UID
getent passwd <UID>

# Move that user to a free UID
sudo usermod -u <NEW_UID> <username>
sudo groupmod -g <NEW_GID> <groupname>

# Then run the sync playbook
ansible-playbook playbooks/fix/08_sync_slurm_uid.yaml -K
```

**MPI jobs fail with PMI errors**

Verify `MpiDefault=pmix` is in `slurm.conf` and `slurm-libpmi` is installed on compute nodes. Also check:

```bash
cat /etc/profile.d/pmix.sh
# Should show: export PMIX_MCA_psec=native
```

**slurmdbd fails to start**

Check file permissions and MariaDB status:

```bash
ls -la /etc/slurm/slurmdbd.conf   # must be -rw------- slurm slurm
sudo systemctl status mariadb
ansible-playbook playbooks/fix/04_fix_slurmdb.yaml -K
```

**seff shows no memory data**

Requires `JobAcctGatherType=jobacct_gather/cgroup` in slurm.conf, `ConstrainRAMSpace=yes` in cgroup.conf, and cgroup v2:

```bash
stat -fc %T /sys/fs/cgroup   # must show cgroup2fs
```

**Full reset needed**

```bash
# WARNING: kills all running jobs
ansible-playbook playbooks/fix/07_slurm_hard_reset.yaml -K
```
