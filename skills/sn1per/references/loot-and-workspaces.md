# Sn1per loot and workspaces

## Where loot lives

Always run with `-w <workspace>`. Inside the container:

```
/usr/share/sniper/loot/workspace/<workspace>/
├── domains/         # targets.txt, per-target domain lists, domains-all-sorted.txt
├── ips/             # live hosts, ips-all-sorted.txt
├── nmap/            # nmap-<target>.xml/.txt, openports-*.txt, livehosts-*.txt
├── web/             # headers-*, title-*, dirsearch/spider output, webhosts-*.txt
├── screenshots/     # site screenshots (<9 KB ones are auto-purged)
├── vulnerabilities/ # vulnerability-report-<target>.txt, risk reports, sc0pe output
├── osint/           # OSINT stage output (-o)
├── credentials/     # found credentials — REDACT when reporting to chat
├── reports/         # HTML reports (aha-converted from raw output), CSV exports
├── output/          # raw transcripts: sniper-<target>-<mode>-<timestamp>.txt
├── notes/           # notepad, metasploit notes
└── scans/           # tasks.txt, running_*.txt (in-flight), notifications*.txt,
                     # scheduled/{daily,weekly,monthly}.sh
```

Copy a workspace to the host:

```bash
mkdir -p loot-out
podman cp sn1per:/usr/share/sniper/loot/workspace/<ws> ./loot-out/
```

(If you used `sudo podman` in the container, use `sudo podman cp` here too.)

## Reading a scan

Order that works well:

1. `scripts/validate_workspace.sh <path>` — confirms the tree is complete and
   whether output files exist.
2. `output/sniper-*.txt` — the raw transcript; everything else is derived. Skim
   phase banners (`PORT SCAN`, `WEB`, `VULN`…) and note errors/timeouts.
3. `nmap/openports-sorted.txt`, `nmap/nmap-<target>.xml` — ports and services.
4. `vulnerabilities/` — per-target findings; rank by severity, distinguish
   confirmed vs version-only guesses.
5. `reports/*.html` — pretty views of the raw output (for the user, not for you).

Diffs across rescans (continuous testing): `loot()` sorts and diffs
`targets-all-sorted.txt` vs `domains-all-sorted.txt` (new domains) and
`openports-sorted.txt` / `livehosts-sorted.txt` (port/host changes); change
notifications accumulate in `scans/notifications.txt`.

## Workspace management

```bash
sniper --list                                  # or: ls .../loot/workspace/
sniper -w <ws> --reimport                      # rebuild sorted loot + reports
sniper -w <ws> --export                        # tar → /usr/share/sniper/loot/<ws>.tar
sniper -w <ws> --reload                        # open workspace HTML report
sniper -w <ws> -d                              # delete workspace (interactive!)
sniper -w <ws> -t <host> -dh                   # remove one host from workspace
```

Never run `-d` / `-dh` without telling the user exactly what will be removed.

## In-flight / status checks (scripted)

```bash
podman exec sn1per ps -ef | grep -v grep | grep sniper   # running?
podman exec sn1per ls /usr/share/sniper/loot/workspace/<ws>/scans/  # running_*.txt
```

`sniper --status` is a `watch`-based live view — interactive TTY only.

## Reporting hygiene

- Summarize: live hosts → open ports/services → findings by severity → next steps.
- Do **not** paste `credentials/` contents or secrets into chat; reference them.
- Treat loot as sensitive data: keep it out of git, public dirs, and shared logs.
