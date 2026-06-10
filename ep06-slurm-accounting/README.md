# Episode 6: Slurm Accounting, QOS, and Fair Share

Configuration files and scripts for [Episode 6 of HPC From Scratch](https://theloginnode.com/posts/2026/06/hpc_from_scratch_06/). The blog post covers what each piece does and why. This directory is the source of the files referenced in that post.

## Files

| File | Purpose |
| --- | --- |
| [`configs/slurm.conf.priority`](configs/slurm.conf.priority) | Priority and fair share lines to append to `/etc/slurm/slurm.conf` |
| [`scripts/setup_accounting.sh`](scripts/setup_accounting.sh) | All sacctmgr commands: accounts, users, QOS, and verification |

## Before You Start

**1. Confirm slurmdbd is running**

The fair share priority type requires slurmdbd to be accessible at slurmctld startup. Verify it is healthy before making any changes:

```
sudo systemctl status slurmdbd
```

**2. Create demo users in FreeIPA**

`setup_accounting.sh` adds testuser1 and testuser2 to Slurm accounting. These must exist as real system users first or jobs will not run. Create them in FreeIPA before running the script:

```
ipa user-add testuser1 --first=Test --last=User1
ipa user-add testuser2 --first=Test --last=User2
```

**3. Note on sudo**

`sacctmgr` write operations (add, modify, delete) require admin access. Since wpaik has `AdminLevel=None` in Slurm, all commands in `setup_accounting.sh` that modify the database use `sudo`. Read-only commands like `sacctmgr show` do not require it.

## Setup Order

> **Note:** The sacctmgr commands in step 1 are not idempotent. Running them twice will error on accounts or users that already exist. Check current state with `sacctmgr show associations` before running.

**Step 1: Run the accounting setup script**

```
cd scripts
bash setup_accounting.sh
```

Or run the commands manually section by section. The script is organized into:
1. Create sub-accounts (`research`, `demo`) under root
2. Add users to accounts
3. Create QOS levels (`normal`, `high`, `gpu`)
4. Assign QOS to accounts
5. Verification output

**Step 2: Update partition definitions in slurm.conf**

On `arbiter`, replace the existing `PartitionName=` lines in `/etc/slurm/slurm.conf` with:

```
PartitionName=cpu Nodes=interceptor-[01-02] Default=YES MaxTime=1-00:00:00 DefaultTime=01:00:00 State=UP
PartitionName=gpu Nodes=corsair-01 Default=NO MaxTime=08:00:00 DefaultTime=01:00:00 AllowQos=normal,gpu State=UP
```

**Step 3: Append priority settings to slurm.conf**

```
cat configs/slurm.conf.priority >> /etc/slurm/slurm.conf
```

This adds the fair share priority settings and `AccountingStorageEnforce=associations,qos`. The enforce line is required for Slurm to actually reject jobs that violate QOS access at submission time. Without it, sacctmgr QOS assignments are stored but never checked.

**Step 4: Distribute slurm.conf and restart**

```
ansible all_nodes -b -m copy \
  -a "src=/etc/slurm/slurm.conf dest=/etc/slurm/slurm.conf owner=slurm group=slurm mode=0644"

sudo systemctl restart slurmctld
sudo scontrol reconfigure
```

`scontrol reconfigure` is required after restarting slurmctld. Without it, compute node slurmd daemons hold the old config hash and Slurm logs config mismatch warnings.

**Step 5: Verify**

```
# Account and QOS structure
sacctmgr show associations format=cluster,account,user,share,qos,defaultqos
sacctmgr show qos format=name,priority,maxwall,flags

# Fair share tree
sshare -l

# Partition limits -- GPU partition should show AllowQos=normal,gpu
scontrol show partition cpu
scontrol show partition gpu
```

Expected GPU partition output after applying:

```
PartitionName=gpu
   AllowGroups=ALL AllowAccounts=ALL AllowQos=normal,gpu
   DefaultTime=01:00:00 MaxTime=08:00:00
   Nodes=corsair-01
```

If `AllowQos=ALL` or `MaxTime=UNLIMITED` is still showing, see Troubleshooting below.

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

## Troubleshooting

**Partition still shows `AllowQos=ALL` after reconfigure**

Confirm the `PartitionName=gpu` line in slurm.conf was updated on arbiter:

```
grep "PartitionName=gpu" /etc/slurm/slurm.conf
```

Should contain `AllowQos=normal,gpu`. If it does, verify the file reached all nodes:

```
ansible all_nodes -b -m shell -a "grep 'PartitionName=gpu' /etc/slurm/slurm.conf"
```

Re-run the copy task if any node has the old version, then restart and reconfigure:

```
sudo systemctl restart slurmctld
sudo scontrol reconfigure
scontrol show partition gpu | grep AllowQos
```

**Config hash mismatch warnings after restart**

```
error: Node interceptor-01 appears to have a different slurm.conf than the slurmctld.
```

Run `sudo scontrol reconfigure`. This signals all slurmd daemons to re-read slurm.conf and recompute the hash.

**sacctmgr add returns "already exists"**

Check current state and use `modify` instead of `add`:

```
sacctmgr show associations
sudo sacctmgr -i modify account name=research set fairshare=80
```

**sshare shows no data or all zeros**

`PriorityType=priority/multifactor` is not active. Verify the setting took effect:

```
scontrol show config | grep PriorityType
```

If it still shows `basic`, restart slurmctld and re-run `scontrol reconfigure`.

**Job rejected: "Invalid qos specification"**

The user's account does not have that QOS in its allowed list:

```
sacctmgr show associations format=account,user,qos where user=<username>
sudo sacctmgr -i modify account name=<account> set qos=normal,high
```
