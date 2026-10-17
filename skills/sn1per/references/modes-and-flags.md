# Sn1per modes and flags

All commands run **inside the container** (`podman exec sn1per sniper …` or an
interactive shell). Always pass `-t <target>` (or `-f <file>`) and `-w <workspace>`.

## Scan modes (`-m <mode>`)

| Mode | What it does | Intrusiveness |
|---|---|---|
| `normal` (default) | Active + passive scan of the target and its open ports | Medium |
| `stealth` | Quick, mostly non-intrusive enumeration (WAF/IPS friendly) | Low |
| `flyover` | Fast multi-threaded high-level scan of many hosts | Medium |
| `airstrike` | Open-port enumeration + fingerprinting over a host file (`-f`) | Medium |
| `nuke` | Full audit of every target in a host file (brute + fullport + OSINT + recon) | **High — explicit opt-in required** |
| `discover` | Walks a CIDR, runs Sn1per on every live host | **High — authorized ranges only** |
| `port` | Scan a single port (`-p` required) | Low |
| `fullportonly` | Full TCP/UDP port scan, results to nmap XML (nmap only, no extra tools) | Medium |
| `web` | Web app scan of ports 80 + 443 only | Medium |
| `webporthttp` / `webporthttps` | Web app scan of one HTTP/HTTPS port (`-p`) | Medium |
| `webscan` | Full HTTP+HTTPS web app scan via Burp Suite + Arachni | Medium-High |
| `vulnscan` | OpenVAS vulnerability scan | Medium-High |
| `massportscan` / `massweb` / `masswebscan` / `massvulnscan` | Mass variants over `-f targets.txt` | **High — authorized lists only** |

## Flags

| Flag | Meaning |
|---|---|
| `-t <target>` | Target domain or IP |
| `-f <file>` | Host list file (mass modes) |
| `-m <mode>` | Scan mode (table above) |
| `-w <name>` | **Workspace — always pass it.** Loot goes to `/usr/share/sniper/loot/workspace/<name>/`; `/` in the name becomes `-` |
| `-p <port>` | Port for `port` / `webporthttp(s)` modes |
| `-b` | Enable bruteforce (explicit opt-in) |
| `-o` | Add OSINT stage |
| `-re` | Add recon stage |
| `-fp` | Full port scan flag (used with the default/normal flow) |
| `-nl` / `-n` | No loot / no report for this run |
| `-c <file>` | Use a preset config (see below); copies it over `/root/.sniper.conf` |
| `-v` | Verbose output |
| `-db` | Debug output |
| `-rr` | Remove resume files (use when a rerun skips work after an interruption) |
| `-u` / `--update` | Update Sn1per (inside the container this rebuilds from GitHub) |
| `--reimport` (`-ri`) | Regenerate sorted loot + reports for a workspace |
| `--reimportall` (`-ria`) | Reimport including updated-targets merge |
| `--reload` (`-rl`) | Open the workspace HTML report |
| `--export` | Tar the workspace to `/usr/share/sniper/loot/<ws>.tar` (needs `-w`) |
| `--list` | List workspaces (tries to open a browser — headless: use `ls` instead) |
| `--status` | Live process view via `watch` (interactive TTY only) |
| `-s daily\|weekly\|monthly` | Edit the schedule script for a workspace (`-w` required). NOTE: bare `-s` is the schedule switch, **not** status — use `--status` for status |
| `-d` | Delete a workspace (interactive confirm, needs `-w`) |
| `-dh` / `-dt` | Delete a host / its tasks from a workspace (needs `-w`, `-t`) |

## Config presets (`-c conf/<name>`)

Preset files live in the repo's `conf/` (and `/usr/share/sniper/conf/` inside the
container). Pass one with `-c`, e.g.

```bash
sniper -c /usr/share/sniper/conf/bug_bounty_quick -t sn1per-target -m web -w ws
```

Available: `default`, `bug_bounty_quick`, `bug_bounty_full_brute`,
`bug_bounty_max_javascript_files`, `bug_bounty_quick_port_80_443_only`,
`deep_active_recon`, `fast_service_portscan`, `super_stealth_mode`,
`super_stealth_mode_OSINT`, `web_mode_all_plugins`, `webpwn_only`,
`webpwn_only_metasploit_disabled`, `zap_only_webscan`.

Key tunables in config: `NMAP_OPTIONS`, `FULL_PORTSCAN_PORTS` (default
`T:1-65535` + a UDP set), Slack toggles, API keys (persisted separately in
`/root/.sniper_api_keys.conf`).

## Typical recipes

```bash
# Safe lab smoke test (nmap only)
sniper -t sn1per-target -m fullportonly -w smoketest

# Web-focused pass
sniper -t sn1per-target -m web -w smoketest

# Authorized real target, default scan + OSINT + recon
sniper -t example.com -o -re -w engagement1

# Regenerate reports after loot changes
sniper -w engagement1 --reimport
```
