# Episode 6: Slurm Accounting, QOS, and Fair Share

Reference files for [the blog post](https://theloginnode.com/posts/hpc-from-scratch-06/).

This episode builds the accounting layer on top of the Slurm install from Episode 5: account hierarchy in sacctmgr, QOS policies, and fair share scheduling. It also adds time limits to the partitions.

Unlike previous episodes, there are no Ansible playbooks here. Most of this work is interactive sacctmgr commands and a small addition to `slurm.conf`. The setup script collects all sacctmgr commands in one place for reference.

---

## Files

| File | Description |
| --- | --- |
| [`scrtips/setup_accounting.sh`](scripts/setup_accounting.sh) | All sacctmgr commands: accounts, users, QOS, verification |
| [`configs/slurm.conf.priority`](configs/slurm.conf.priority) | Priority and fair share lines to add to `/etc/slurm/slurm.conf` |

---

## Applying the Changes

### 1. Run the accounting setup

The setup script is a reference, not a one-shot installer. Read through it and run the commands in order, verifying output at each step. Some commands are not idempotent: adding an account that already exists returns an error.

```bash
# On arbiter or carrier (anywhere sacctmgr is available)
bash setup_accounting.sh
```

Or run the commands manually section by section, which is what the blog post does.

### 2. Add priority settings to slurm.conf

Copy the contents of `slurm.conf.priority` and append them to `/etc/slurm/slurm.conf` on `arbiter`. The file must be identical on all nodes:

```bash
# Append to existing slurm.conf on arbiter
cat slurm.conf.priority >> /etc/slurm/slurm.conf

# Distribute to all nodes
ansible all_nodes -b -m copy \
  -a "src=/etc/slurm/slurm.conf dest=/etc/slurm/slurm.conf owner=slurm group=slurm mode=0644"

# Restart the controller
sudo systemctl restart slurmctld
```

Compute nodes (slurmd) do not need to restart.

### 3. Update partition definitions

The partition lines in `slurm.conf` also change in this episode (adding `MaxTime` and `DefaultTime`). Replace the existing `PartitionName=` lines with:

```
PartitionName=cpu Nodes=interceptor-[01-02] Default=YES MaxTime=1-00:00:00 DefaultTime=01:00:00 State=UP
PartitionName=gpu Nodes=corsair-01 Default=NO MaxTime=08:00:00 DefaultTime=01:00:00 AllowQos=normal,gpu State=UP
```

---

## Verification

```bash
# Account and association tree
sacctmgr show associations format=cluster,account,user,share,fairshare,qos,defaultqos

# QOS definitions
sacctmgr show qos format=name,priority,maxwall,flags

# Fair share tree (run after submitting some jobs to see scores shift)
sshare -l

# Job priority breakdown (with jobs in queue)
sprio -l

# Partition limits
scontrol show partition cpu
scontrol show partition gpu
```

---

## Account Structure

```
cluster
└── root
    ├── research  (share=80)
    │   ├── wpaik
    │   └── testuser1
    └── demo  (share=20)
        └── testuser2
```

Adjust account names, share weights, and users to match your cluster.
