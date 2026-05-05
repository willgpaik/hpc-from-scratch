# HPC From Scratch

Configuration files and command references for [The Login Node](https://theloginnode.com)'s **HPC From Scratch** series: a six-node home HPC cluster built for under $1,300.

Each episode has its own directory with templates and a short troubleshooting guide. The blog posts cover the "why" and walk through everything step by step. This repo is the source of truth for the configuration files referenced in those posts.

## Episodes

| Episode | Topic | Blog | Directory |
|--------|-------|------|-----------|
| 1 | Building Real HPC on a Budget | [post](https://theloginnode.com/posts/2026/03/hpc_from_scratch_01/) | — |
| 2 | RAM, NVMe, and the iGPU Memory Trap | [post](https://theloginnode.com/posts/2026/03/hpc_from_scratch_02/) | — |
| 3 | The WiFi Login Node | [post](https://theloginnode.com/posts/2026/04/hpc_from_scratch_03/) | [ep03-network-os/](ep03-network-os/) |
| 4 | The WiFi Login Node | [post](https://theloginnode.com/posts/2026/05/hpc_from_scratch_04/) | [ep04-storage-auth/](ep04-storage-auth/) |

## The Cluster

| Hostname | Hardware | Role |
|----------|----------|------|
| `carrier` | Lenovo IdeaPad 1 | Login node (WiFi + Ethernet bridge) |
| `arbiter` | Lenovo ThinkCentre M715q | Management, NFS server |
| `interceptor-01` | Lenovo ThinkCentre M715q | Compute |
| `interceptor-02` | Lenovo ThinkCentre M715q | Compute |
| `observer` | Lenovo ThinkCentre M715q | Visualization |
| `corsair-01` | HP Envy TE01 | GPU compute |

All nodes run Rocky Linux 9. The internal cluster subnet is `192.168.50.0/24`, physically isolated from the home network by a Netgear GS308E gigabit switch. The login node bridges WiFi (home network) and Ethernet (cluster).

## Using This Repo

Each episode directory contains:

- Configuration file templates with sensible defaults
- A short README with destination paths and troubleshooting tips

Copy the templates to the paths listed in each episode's README, substitute any `<PLACEHOLDERS>`, and follow the blog post for the walkthrough.

## Connect

- Blog: [theloginnode.com](https://theloginnode.com)
- YouTube: [@the_login_node](https://www.youtube.com/@the_login_node)
- LinkedIn: [Ghanghoon Paik](https://www.linkedin.com/in/ghanghoon-paik-88464649)
