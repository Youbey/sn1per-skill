# Sn1per skill troubleshooting

## Containers / podman

**`--privileged` denied, `sleep infinity` refused, or scans find no ports (rootless)**
Rootless podman often cannot grant what nmap's SYN/UDP scans need. Recreate the
containers with rootful podman — and stay consistent (rootless and rootful have
**separate image stores**, so mixing gives `image not found`):

```bash
sudo podman network create sn1per-lab
sudo podman run -d --name sn1per-target --network sn1per-lab docker.io/library/nginx:alpine
sudo podman run -d --name sn1per --network sn1per-lab --privileged sn1per-kali-linux sleep infinity
sudo podman exec sn1per sniper -t sn1per-target -m fullportonly -w smoketest
sudo podman cp sn1per:/usr/share/sniper/loot/workspace/smoketest ./loot-out/
```

**`podman cp: no such container`**
The scanner container was removed (`--rm`, reboot, or `podman system reset`).
Recreate it (Step 2 in SKILL.md). It is kept alive with `sleep infinity` precisely
so loot stays addressable.

**Name already in use**
```bash
podman rm -f sn1per sn1per-target
```
Then rerun the create commands. Compose's own container is named `kali-linux`
(`docker-compose.yml`) — it will also collide if running; remove it too if present.

**Build failures (`scripts/build-image.sh`)**
- First build is several GB / 30–60+ min (Kali full-upgrade + Metasploit + Sn1per
  install). Check the log if backgrounded: `/tmp/sn1per-build.log`.
- Install prompt kills the build (`Do you want to continue? (y/n)` → exit 1), or
  install.sh dies on the Arachni 404 download (exit 8): you bypassed the wrapper —
  use `scripts/build-image.sh` (it patches both), don't `podman build` the raw
  Dockerfile directly. Consequence of the Arachni skip: `webscan` mode unavailable.
- No space: `df -h`, free space, retry.
- Rootless OOM/permission errors: `sudo bash …/build-image.sh <repo-root>` (and
  switch to `sudo podman` consistently afterward).
- `sniper -u force` during build needs network access.

**Compose vs direct run**
`podman-compose up` starts the image's default `CMD ["sniper"]`, which exits
immediately (no target). Prefer the long-lived `sleep infinity` container +
`podman exec` pattern from SKILL.md.

## Scans

**Scan starts but finds nothing / raw-socket errors**
Privileged/root problem (see above), or the target name does not resolve — confirm
both containers are on `sn1per-lab`:
```bash
podman exec sn1per getent hosts sn1per-target
```

**Rerun seems to skip phases / resumes oddly**
Stale resume state — clear it: `sniper -t <T> -m <mode> -w <ws> -rr`.

**Scan died mid-run**
Check `scans/running_*.txt`; remove stale ones, then rerun with `-rr`. Output
collected so far is still in `output/` — copy loot out before rebuilding the
container.

**`sniper` says "must be run as root"**
You are on the host. There is no host install — run it inside the container
(`podman exec sn1per sniper …`), where the shell is already root.

**Slow full port scan**
`fullportonly` covers T:1-65535 + UDP (configurable `FULL_PORTSCAN_PORTS`). For a
quick check use `-m port -p <port>` or `-m web`.

**Offline / update warnings**
Sn1per phones home for version checks; in an egress-restricted environment it
falls back to offline mode — harmless for local scans.

## Loot / reports

**Empty or partial workspace**
- Was `-w` passed? Without it loot lands in a catch-all path. Use `-w` always.
- Did the scan finish? `output/sniper-*.txt` should exist; re-run
  `sniper -w <ws> --reimport` to rebuild sorted lists and HTML reports.

**`validate_workspace.sh` reports missing dirs**
A partial copy (scan still running during `podman cp`) — recopy after the scan
exits, or copy individual files.

**`--status` / `--list` behave strangely**
Both are interactive (`watch`, browser). Use the scripted checks in
[loot-and-workspaces.md](loot-and-workspaces.md) instead.

## Config

- Presets via `-c /usr/share/sniper/conf/<name>`; it **overwrites**
  `/root/.sniper.conf` (backup taken automatically).
- API keys (Shodan, Censys, …) belong in `/root/.sniper_api_keys.conf` inside the
  container so they survive config swaps. Never commit them; container rebuilds
  wipe them (re-add after rebuild).
