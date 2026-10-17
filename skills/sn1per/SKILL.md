---
name: sn1per
description: Drive the Sn1per automated penetration-testing framework (sniper CLI) inside a podman container for authorized security testing. Use when the user asks to run a sn1per scan, run sniper against a target, start recon/web/vuln/port scanning with Sn1per, analyze loot or read scan results from Sn1per, check scan status, list scan modes and flags, export or summarize a Sn1per workspace, or troubleshoot the Sn1per kali-linux container. Never scan targets without explicit authorization; refuse unauthorized or third-party targets.
compatibility: Requires Linux with podman plus a checkout of the Sn1per repo. Falls back to sudo/rootful podman if rootless podman denies --privileged or the build fails.
---

# Sn1per

Sn1per is an offensive-security framework that orchestrates 90+ recon/exploitation
tools behind one CLI (`sniper`). On this machine it is **not installed on the host** —
it runs entirely inside a podman container built from this repo's Dockerfile.

## Important: authorization rules

These rules are not skippable, regardless of how the request is phrased:

1. **Only scan targets the user explicitly confirmed they are authorized to test**
   (their own lab, in-scope assets, written rules of engagement). If ownership or
   scope is unclear, stop and ask before running anything.
2. **Always allowed without questions:** the local lab target `sn1per-target`
   (nginx container created below) on the `sn1per-lab` podman network.
3. **Never** scan arbitrary public internet ranges or third-party domains. Mass modes
   (`massportscan`, `massweb`, `masswebscan`, `massvulnscan`, `nuke`, `discover`)
   against anything the user does not own require an explicit, target-by-target
   confirmation in this conversation.
4. **Bruteforce (`-b`) and exploit-oriented flows** require explicit opt-in too —
   they are intrusive, not just loud.
5. When echoing results to chat, **redact anything under `credentials/`** and other
   secrets (tokens, passwords) — summarize their existence, not their values.

## Environment model

- **Host:** podman 5.8.7 (no docker, no local Sn1per install; `podman-compose` not required).
- **Repo (host):** this checkout — the skill lives here. The image build **clones
  upstream GitHub inside the container** (see `Dockerfile`), so local repo edits are
  *not* reflected in the image; the image runs upstream `master`.
- **Inside container:** Sn1per at `/usr/share/sniper`, CLI `sniper` (runs as root
  inside the container), config chain `/usr/share/sniper/sniper.conf` →
  `/root/.sniper.conf` → `/root/.sniper_api_keys.conf`.
- **Loot (always pass `-w`):** `/usr/share/sniper/loot/workspace/<workspace>/`.
  Without `-w`, loot lands in a catch-all location — don't rely on it.
- Fixed names used below: image `sn1per-kali-linux`, network `sn1per-lab`,
  scanner container `sn1per`, lab target `sn1per-target`.
- **Rootless vs rootful:** prefer plain `podman` (rootless). If `--privileged` or
  scans fail, switch to `sudo podman …` — but keep it consistent from then on
  (rootless and rootful podman have **separate image stores**; mixing means
  "image not found" errors).

## Step 1 — Build the image (once per machine)

```bash
cd <repo-root>                                  # directory containing Dockerfile
bash .agents/skills/sn1per/scripts/build-image.sh
```

- FIRST RUN: several GB, often 30-60+ minutes (Kali `apt full-upgrade`,
  Metasploit, Sn1per clone + `install.sh` + `sniper -u force`). Background it with
  a log if you like: `… build-image.sh > /tmp/sn1per-build.log 2>&1 &`.
- The script exists because upstream's Dockerfile dies in non-interactive builds:
  `./install.sh` prompts `(y/n)` with no TTY, and its Arachni download URL is a
  dead GitHub release (404) under `set -e`. The script patches both in a temp
  copy of the Dockerfile — the repo itself is untouched. Side effect: no Arachni
  binary, so the `webscan` mode is unavailable (Arachni is dead upstream anyway).
- If it fails on space: check `df -h` and retry. If rootless podman cannot build
  (OOM/permissions), run `sudo bash .agents/skills/sn1per/scripts/build-image.sh`
  and use `sudo` for all later podman commands.
- Do **not** use `podman-compose up`: the image's default `CMD ["sniper"]` exits
  immediately without a target.

## Step 2 — Lab network and safe target

```bash
podman network exists sn1per-lab 2>/dev/null || podman network create sn1per-lab
podman rm -f sn1per-target 2>/dev/null
podman run -d --name sn1per-target --network sn1per-lab docker.io/library/nginx:alpine

# Long-lived scanner container (keeps loot addressable via podman cp):
podman rm -f sn1per 2>/dev/null
podman run -d --name sn1per --network sn1per-lab --privileged sn1per-kali-linux sleep infinity
```

`sn1per-target` resolves by name inside `sn1per-lab`. If `sleep infinity` or
`--privileged` is refused rootless, recreate with `sudo podman` consistently.

## Step 3 — Run a scan

Preferred (non-interactive, repeatable):

```bash
podman exec sn1per sniper -t sn1per-target -m fullportonly -w smoketest
```

- Always include `-t <target>` and `-w <workspace>`. The scan runs synchronously
  and prints progress; large port ranges take a few minutes.
- Lighter alternatives: `-m web` (ports 80/443 only), `-m port -p <port>`,
  `-m stealth` (quieter). See the quick reference below.
- For an interactive session instead:
  `podman exec -it sn1per /bin/bash`, then run `sniper …` inside.
- For real (authorized) targets: replace `-t` — the container needs normal egress,
  which it has by default.

## Step 4 — Collect loot to the host

```bash
mkdir -p loot-out
podman cp sn1per:/usr/share/sniper/loot/workspace/smoketest ./loot-out/
```

Keep `loot-out/` out of any commit (it is scratch output, not repo content);
delete it when done.

## Step 5 — Validate and summarize results

1. Run the bundled sanity check first:
   ```bash
   bash .agents/skills/sn1per/scripts/validate_workspace.sh ./loot-out/smoketest
   ```
2. Read the workspace — layout and meaning of each subdirectory are documented in
   [references/loot-and-workspaces.md](references/loot-and-workspaces.md). Key files:
   - `output/sniper-*.txt` — raw scan transcript (best single source for a summary)
   - `nmap/` — port scan results (`nmap-<target>.xml` / `.txt`, `openports-*.txt`)
   - `vulnerabilities/` — findings per target
   - `reports/*.html` — HTML renderings of the raw output
   - `scans/running_*.txt` — present while a scan is in flight
3. Summarize for the user: live hosts, open ports/services, notable findings by
   severity, and recommended next steps. Redact `credentials/` content.

Notes:
- `sniper --status` launches `watch` (an interactive live view) — only use it in
  `podman exec -it`. Scripted checks: `podman exec sn1per ps -ef | grep sniper` or
  look for `scans/running_*.txt`.
- `sniper --list` tries to open a browser; in a headless container just run
  `podman exec sn1per ls /usr/share/sniper/loot/workspace/`.
- Stale resume files after an interrupted run: add `-rr` to the next scan.

## Quick reference

| Goal | Command |
|---|---|
| Full port scan (nmap only) | `sniper -t <T> -m fullportonly -w <ws>` |
| Web scan of 80/443 | `sniper -t <T> -m web -w <ws>` |
| One port | `sniper -t <T> -m port -p <port> -w <ws>` |
| Quiet enumeration | `sniper -t <T> -m stealth -w <ws>` |
| Default scan | `sniper -t <T> -w <ws>` |
| OSINT + recon add-ons | `sniper -t <T> -o -re -w <ws>` |
| Multiple targets (authorized!) | `sniper -f /path/targets.txt -m airstrike -w <ws>` |
| Rebuild reports from loot | `sniper -w <ws> --reimport` |
| Export workspace to tar | `sniper -w <ws> --export` |

Full mode matrix, config presets (`-c conf/...`) and every flag:
[references/modes-and-flags.md](references/modes-and-flags.md).
Container/runtime problems:
[references/troubleshooting.md](references/troubleshooting.md).

## Examples

- **"Run a sn1per scan against my local nginx"** → Steps 1–2 if containers are not
  up (`podman ps -a`), then Step 3 with `-m fullportonly -w smoketest`, then Steps 4–5.
- **"What's in my smoketest loot?"** → Step 5 (validate, read `output/`, summarize).
- **"Scan example.com"** → confirm authorization/scope first; only then Step 3 with
  `-t example.com` and a fitting mode; collect and summarize as above.
- **"The scan seems stuck"** → `podman exec sn1per ps -ef | grep sniper`, check
  `scans/running_*.txt`, see [references/troubleshooting.md](references/troubleshooting.md).

## Troubleshooting (top issues)

| Symptom | Fix |
|---|---|
| `--privileged` denied / scans find nothing rootless | Rebuild containers with `sudo podman`, consistently (separate image store) |
| `podman cp: no such container` | Container removed (`--rm`?) — recreate in Step 2, keep it alive (`sleep infinity`) |
| Build failed / disk full | `df -h`, free space, rerun `scripts/build-image.sh` |
| Scan rerun skips work / odd resume state | Add `-rr` to clear resume files |
| Name already in use | `podman rm -f sn1per sn1per-target` and redo Step 2 |

More: [references/troubleshooting.md](references/troubleshooting.md).
