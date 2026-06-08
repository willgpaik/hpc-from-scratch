#!/bin/bash
# setup_accounting.sh
# Slurm accounting setup: accounts, users, QOS, and verification
# Episode 6 - HPC From Scratch | https://theloginnode.com
#
# Run this on arbiter or carrier (anywhere sacctmgr is available).
# This script is a reference: read through it and run section by section,
# verifying output after each step. Commands are not fully idempotent.
#
# Prerequisites:
#   - slurmdbd and slurmctld running (Episode 5)
#   - testuser1 and testuser2 created in FreeIPA (ipa user-add)

set -e

# ============================================================
# 1. Create sub-accounts under root
# ============================================================
# Adjust fairshare values to match your intended allocation.
# These are relative weights: research gets 80/(80+20) = 80% of cluster share.

echo ">>> Creating accounts..."

sudo sacctmgr -i add account research \
  parent=root \
  Description="Research Group" \
  Organization="Cluster" \
  fairshare=80

sudo sacctmgr -i add account demo \
  parent=root \
  Description="Demo Group" \
  Organization="Cluster" \
  fairshare=20

# ============================================================
# 2. Add users to accounts
# ============================================================
# wpaik already has an association under root from Episode 5.
# Adding to research creates a second association and sets it as default.
# Users can belong to multiple accounts simultaneously.

echo ">>> Adding users..."

sudo sacctmgr -i add user wpaik \
  account=research \
  defaultaccount=research

sudo sacctmgr -i add user testuser1 \
  account=research \
  defaultaccount=research

sudo sacctmgr -i add user testuser2 \
  account=demo \
  defaultaccount=demo

# ============================================================
# 3. Create QOS levels
# ============================================================

echo ">>> Creating QOS..."

sudo sacctmgr -i add qos normal
sudo sacctmgr -i modify qos normal set \
  Priority=0 \
  MaxWallDurationPerJob=1-00:00:00

sudo sacctmgr -i add qos high
sudo sacctmgr -i modify qos high set \
  Priority=100 \
  MaxWallDurationPerJob=04:00:00

sudo sacctmgr -i add qos gpu
sudo sacctmgr -i modify qos gpu set \
  Priority=50 \
  MaxWallDurationPerJob=08:00:00

# ============================================================
# 4. Assign QOS to accounts
# ============================================================

echo ">>> Assigning QOS to accounts..."

sudo sacctmgr -i modify account name=research set \
  qos=normal,high,gpu \
  defaultqos=normal

sudo sacctmgr -i modify account name=demo set \
  qos=normal \
  defaultqos=normal

# ============================================================
# 5. Verification
# ============================================================

echo ""
echo "========================================"
echo "Verification"
echo "========================================"

echo ""
echo "--- Association tree ---"
sacctmgr show associations \
  format=cluster,account,user,share,fairshare,qos,defaultqos

echo ""
echo "--- QOS definitions ---"
sacctmgr show qos \
  format=name,priority,maxwall,flags

echo ""
echo "--- Fair share tree ---"
sshare -l

echo ""
echo "Done. Check output above for expected structure."
echo "Run 'scontrol show partition' after applying slurm.conf.priority and restarting slurmctld."
