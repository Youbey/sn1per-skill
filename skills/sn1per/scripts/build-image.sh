#!/usr/bin/env bash
# Build the sn1per-kali-linux image from the repo Dockerfile.
#
# Why this exists: a plain `podman build` of the upstream Dockerfile dies twice
# today, both for environmental reasons, not because the repo is broken locally:
#   1. install.sh prompts "(y/n)" — there is no TTY during `podman build`, so the
#      build aborts at EOF. Fix: pass the documented `force` argument.
#   2. install.sh downloads Arachni v1.5.1 from a GitHub release that no longer
#      exists (404) under `set -e`, killing the install. Fix: pre-create
#      /usr/share/arachni so install.sh's `[[ ! -d ... ]]` guard skips that block.
#      Consequence: no Arachni binary — the `webscan` mode is unavailable (the
#      tool is dead upstream anyway).
# The repo itself is untouched: both fixes are applied to a temp copy of the
# Dockerfile only.
#
# Usage: build-image.sh [repo-root]     (repo-root defaults to current directory)
#   If rootless podman is unusable, rerun with: sudo scripts/build-image.sh <repo-root>
#
# First build downloads several GB (Kali full-upgrade + Metasploit) and takes
# 30-60+ minutes. Progress goes to the terminal (or redirect it to a log).

set -euo pipefail

ROOT="${1:-.}"
cd "$ROOT"
[ -f Dockerfile ] || { echo "ERROR: no Dockerfile found in $ROOT" >&2; exit 1; }

RUNNER=""
if ! podman info >/dev/null 2>&1; then
  echo "rootless podman not usable here; retrying with sudo (rootful store from now on)"
  RUNNER="sudo"
fi

TMP_DOCKERFILE="$(mktemp)"
trap 'rm -f "$TMP_DOCKERFILE"' EXIT
sed 's|&& \./install.sh|\&\& mkdir -p /usr/share/arachni \&\& ./install.sh force|' Dockerfile > "$TMP_DOCKERFILE"

echo "Building sn1per-kali-linux from patched Dockerfile ($(pwd))..."
$RUNNER podman build -f "$TMP_DOCKERFILE" -t sn1per-kali-linux .
echo "OK: image sn1per-kali-linux ready"
