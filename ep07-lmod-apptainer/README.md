# Episode 7: Lmod and Apptainer on Rocky Linux

Configuration files, Ansible playbooks, and example modulefiles for [Episode 7 of HPC From Scratch](https://theloginnode.com/posts/hpc-from-scratch-07/).
The blog post covers what each piece does and why. This directory is the source of the playbooks and configs.

This episode covers two tools: Lmod (software version management via `module load`) and Apptainer (rootless containers for HPC). Both are installed via `dnf` from Rocky Linux 10's own repositories rather than built from source. See the blog post Section 4 and Section 11 for why.

## Files

| File | Purpose |
|------|---------|
| `modulefiles/gcc/12.5.0.lua` | Example GCC modulefile (update version to match your install) |
| `modulefiles/python/3.12.12.lua` | Example Python modulefile (update version to match your install) |
| `modulefiles/openmpi/5.0.9.lua` | Example OpenMPI modulefile with `depends_on` GCC (update versions) |
| `examples/hello.def` | Example Apptainer definition file (Ubuntu + Python script) |
| `examples/hello.py` | Script bundled into the example container |
| `playbooks/01_install_lmod.yaml` | Install Lmod via dnf, deploy custom MODULEPATH profile.d script, pin against upgrades |
| `playbooks/02_setup_modulefiles.yaml` | Rename `/shared/sw/modules` to `/shared/sw/modulefiles` on arbiter |
| `playbooks/03_install_apptainer.yaml` | Install Apptainer via dnf, pin against upgrades |

## Setup Order

```bash
ansible-playbook playbooks/01_install_lmod.yaml -K
ansible-playbook playbooks/02_setup_modulefiles.yaml -K
ansible-playbook playbooks/03_install_apptainer.yaml -K
```

Each install playbook pins its own package against accidental dnf upgrades, using `excludepkgs` in `/etc/dnf/dnf.conf`. The pinning task reads whatever is already on the `excludepkgs` line, adds its own package if not already present, and writes the combined list back. This makes the order of `01` and `03` irrelevant: neither needs to know about the other's pinned package, and a future episode that pins another package can reuse the same two-task pattern (read current value, append-and-deduplicate).

After the playbooks complete, copy your modulefiles to `/shared/sw/modulefiles/`. The files in `modulefiles/` in this repo are starting points. Update versions to match what is installed on your cluster:

```bash
ls /shared/sw/python/   # confirm installed version
ls /shared/sw/gcc/
ls /shared/sw/openmpi/
```

Verify:

```bash
module --version
module load python/3.12.12
python3 --version

apptainer --version
```

## Building a Container Image

Build on a personal workstation or other local-disk machine, then copy the resulting `.sif` to the cluster:

```bash
# On your local workstation, NOT on the cluster:
apptainer build hello.sif examples/hello.def

# Copy to the cluster:
scp hello.sif carrier:/scratch/wpaik/

# Run on the cluster, no fakeroot needed for running a finished .sif:
ssh interceptor-01 'apptainer run /scratch/wpaik/hello.sif'
```

## Troubleshooting

**`module: command not found`**

Open a new terminal session; profile.d scripts only apply to new logins. Confirm the RPM is installed: `rpm -q Lmod`.

**`module avail` does not show `/shared/sw/modulefiles`**

Check `echo $MODULEPATH`. Confirm `/etc/profile.d/z00-shared-modulepath.sh` exists and sorts after `modules.sh` alphabetically (the `module` command has to exist before `module use` works). Also check the file's `if [ -n "$LMOD_CMD" ]` guard isn't silently skipping the `module use` call. That only happens if Lmod's own init never ran on that node.

**`depends_on` loads the wrong GCC**

The example OpenMPI modulefile uses `depends_on("gcc/12.5.0")`. Update this line if your GCC version differs.

**Lmod or Apptainer got upgraded unexpectedly**

Check the pin: `grep excludepkgs /etc/dnf/dnf.conf`. Re-run `playbooks/01_install_lmod.yaml` or `playbooks/03_install_apptainer.yaml` (whichever package needs re-pinning) if missing.

**`--nv` does not expose the GPU**

Confirm `nvidia-smi` works on the host outside any container first. If that works, run `apptainer exec --nv <image> nvidia-smi` for a more specific error.
