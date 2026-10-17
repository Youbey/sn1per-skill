#!/usr/bin/env bash
# Read-only sanity check for a Sn1per loot workspace directory.
# Usage: validate_workspace.sh <path-to-workspace>
#   e.g. validate_workspace.sh ./loot-out/smoketest
# Exit codes: 0 = valid workspace (warnings allowed), 1 = not a workspace / bad usage.

set -euo pipefail

usage() {
  echo "Usage: $(basename "$0") <path-to-workspace>" >&2
  exit 1
}

[ $# -eq 1 ] || usage
WS="$1"

if [ ! -d "$WS" ]; then
  echo "FAIL: not a directory: $WS" >&2
  exit 1
fi

REQUIRED_DIRS="domains ips screenshots nmap reports output osint credentials web vulnerabilities notes scans"

missing=""
for d in $REQUIRED_DIRS; do
  if [ ! -d "$WS/$d" ]; then
    missing="$missing $d"
  fi
done

if [ -n "$missing" ]; then
  echo "FAIL: $WS is not a Sn1per workspace (missing dirs:$missing)" >&2
  exit 1
fi

echo "OK: $WS looks like a Sn1per workspace"

# Raw scan transcripts — the primary evidence a scan actually produced output.
output_count=$(find "$WS/output" -maxdepth 1 -type f -name 'sniper-*.txt' | wc -l)
if [ "$output_count" -eq 0 ]; then
  echo "WARN: no output/sniper-*.txt transcripts found (scan may not have run or used -nl)"
else
  echo "OK: $output_count raw transcript(s) in output/"
fi

# Non-empty files per directory (empty placeholders are normal right after init).
echo "File counts:"
for d in $REQUIRED_DIRS; do
  n=$(find "$WS/$d" -type f -size +0c 2>/dev/null | wc -l)
  printf '  %-16s %s non-empty file(s)\n' "$d" "$n"
done

# Scan-in-progress detection.
running=0
for f in "$WS"/scans/running_*.txt; do
  if [ -e "$f" ]; then
    running=$((running + 1))
  fi
done
if [ "$running" -gt 0 ]; then
  echo "NOTE: $running running_*.txt marker(s) present — a scan may still be in flight (copy loot after it exits)"
fi

# Headline results if present.
if [ -s "$WS/nmap/openports-sorted.txt" ]; then
  echo "Open host:port entries: $(wc -l < "$WS/nmap/openports-sorted.txt")"
fi
vuln_files=$(find "$WS/vulnerabilities" -type f -size +0c 2>/dev/null | wc -l)
if [ "$vuln_files" -gt 0 ]; then
  echo "Vulnerability files: $vuln_files (review; redact secrets when reporting)"
fi

exit 0
