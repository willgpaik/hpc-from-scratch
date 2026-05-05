#!/bin/bash
# user_creation.sh
# Run on arbiter after kinit admin
# Creates a new HPC user in FreeIPA with NFS home directory,
# XFS quota, and Slurm accounting entry
#
# Usage: bash scripts/user_creation.sh

set -e

QUOTA_BSOFT="18g"
QUOTA_BHARD="20g"
QUOTA_ISOFT="180000"
QUOTA_IHARD="200000"
HOME_ROOT="/nfsdata/home"

echo "Checking Kerberos ticket..."
if ! klist -s; then
    echo "Error: No admin ticket. Run 'kinit admin' first."
    exit 1
fi

echo "========================================"
echo "       New HPC User Registration        "
echo "========================================"
read -p "User ID (e.g. jsmith): " ID
read -p "First name: " FIRST
read -p "Last name: " LAST

if [[ -z "$ID" || -z "$FIRST" || -z "$LAST" ]]; then
    echo "Error: All fields required."
    exit 1
fi

if [[ ! "$ID" =~ ^[a-z][a-z0-9_-]*$ ]]; then
    echo "Error: Username must start with a letter and contain only lowercase letters, numbers, - or _"
    exit 1
fi

echo ""
echo "Creating FreeIPA user: $ID"
ipa user-add "$ID" \
    --first="$FIRST" \
    --last="$LAST" \
    --shell=/bin/bash \
    --homedir="/home/$ID"

echo ""
echo "Setting initial password"
ipa passwd "$ID"

read -p "Remove password expiration? (y/n): " REMOVE_EXPIRY
if [[ "$REMOVE_EXPIRY" == "y" ]]; then
    ipa user-mod "$ID" --password-expiration=20991231235959Z
fi

# Get FreeIPA-assigned UID/GID
# Using numeric IDs is critical for correct NFS ownership
echo ""
echo "Getting FreeIPA-assigned UID/GID..."
USER_UID=$(ipa user-show "$ID" --raw | grep "uidnumber:" | awk '{print $2}')
USER_GID=$(ipa user-show "$ID" --raw | grep "gidnumber:" | awk '{print $2}')

if [[ -z "$USER_UID" || -z "$USER_GID" ]]; then
    echo "Error: Could not retrieve UID/GID from FreeIPA."
    exit 1
fi

echo "UID=$USER_UID GID=$USER_GID"

# Create home directory with FreeIPA UID/GID ownership
echo ""
echo "Creating home directory: $HOME_ROOT/$ID"
if [ ! -d "$HOME_ROOT/$ID" ]; then
    sudo mkdir -p "$HOME_ROOT/$ID"
    sudo chmod 700 "$HOME_ROOT/$ID"
    sudo chown "$USER_UID:$USER_GID" "$HOME_ROOT/$ID"
    sudo mkdir -p "$HOME_ROOT/$ID/.ssh"
    sudo chmod 700 "$HOME_ROOT/$ID/.ssh"
    sudo chown "$USER_UID:$USER_GID" "$HOME_ROOT/$ID/.ssh"
else
    echo "Directory exists. Fixing ownership."
    sudo chown -R "$USER_UID:$USER_GID" "$HOME_ROOT/$ID"
fi

# Apply XFS quota using numeric UID
echo ""
echo "Applying storage quota"
sudo xfs_quota -x -c \
    "limit -u bsoft=${QUOTA_BSOFT} bhard=${QUOTA_BHARD} isoft=${QUOTA_ISOFT} ihard=${QUOTA_IHARD} $USER_UID" \
    $HOME_ROOT

# Add to Slurm accounting
echo ""
echo "Adding $ID to Slurm accounting"
sacctmgr -i add user "$ID" Account=root

echo ""
echo "========================================"
echo "Verification"
echo "========================================"
ipa user-show "$ID" | grep -E "User login:|UID:|GID:|Home directory:|Login shell:"
echo ""
ls -ld "$HOME_ROOT/$ID"
echo ""
sudo xfs_quota -x -c "report -h" $HOME_ROOT | grep -E "^User quota|^$ID" || true
echo ""
sacctmgr show user "$ID" -n
echo ""
echo "User $ID created."
echo "SSH: ssh $ID@carrier.cluster.local"
echo "Password change required on first login."
