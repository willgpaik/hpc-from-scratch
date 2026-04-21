# Episode 3: The WiFi Login Node

Configuration templates for [Episode 3 of HPC From Scratch](https://theloginnode.com/posts/2026/04/hpc_from_scratch_03/). The blog post covers what each piece does and why. This directory is the source of the templates.

## Files

| File | Destination |
|------|-------------|
| [`configs/dnsmasq.conf`](configs/dnsmasq.conf) | `/etc/dnsmasq.conf` |
| [`configs/hosts`](configs/hosts) | append to `/etc/hosts` |
| [`configs/sshd_config.d/99-custom.conf`](configs/sshd_config.d/99-custom.conf) | `/etc/ssh/sshd_config.d/99-custom.conf` |
| [`configs/fail2ban/jail.local`](configs/fail2ban/jail.local) | `/etc/fail2ban/jail.local` |
| [`configs/systemd/sshd-override.conf`](configs/systemd/sshd-override.conf) | created via `sudo systemctl edit sshd.service` |

Substitute `<WIRED INTERFACE>` in `dnsmasq.conf` with the output of `nmcli device`.

## Troubleshooting

Quick checks for things that commonly go wrong. For the full walkthrough, see the blog post.

### Worker does not get an IP

```bash
sudo ss -tulpn | grep dnsmasq
sudo journalctl -u dnsmasq -f
```

If no `DHCPDISCOVER` shows up while the worker boots, the physical link is down. Check switch LEDs and cable seating.

### Worker has an IP but cannot reach the internet

```bash
cat /proc/sys/net/ipv4/ip_forward            # must be 1
sudo firewall-cmd --list-all | grep masquerade   # must show yes
```

If `ip_forward` is 0, re-run the `sysctl` step. If masquerade is missing, re-run `firewall-cmd --add-masquerade --permanent`.

### dnsmasq fails to start

Port 53 conflict with `systemd-resolved` is the usual cause:

```bash
sudo ss -tulpn | grep ':53 '
```

The `interface=` directive in `dnsmasq.conf` binds dnsmasq to the wired interface only, which usually avoids the conflict. If it still fails, disable `systemd-resolved` or move dnsmasq to a different DNS port.

### sshd fails to start after reboot (laptop login nodes)

```bash
systemctl status sshd
journalctl -u sshd -b
```

If it is in a failed state, apply the systemd override:

```bash
sudo systemctl edit sshd.service
```

Paste the contents of [`configs/systemd/sshd-override.conf`](configs/systemd/sshd-override.conf) and save. Reboot to verify.

### ssh-copy-id fails with "Permission denied"

```bash
id <user>                                     # user must exist on the worker
sudo sshd -T | grep passwordauthentication    # should show yes for first-time copy
```

### fail2ban shows 0 failures despite visible brute force

Rocky 9's `fail2ban` reads from the systemd journal, not `/var/log/secure`. `mode = aggressive` (as in the template) handles the journal format correctly. Without it, counts will stay at zero even with real brute force attempts.
