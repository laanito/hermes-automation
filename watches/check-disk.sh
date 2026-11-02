#!/usr/bin/env bash
set -euo pipefail
# Root filesystem use %
use="$(df -P / | awk "NR==2 {gsub(/%/,\"\",\$5); print \$5}")"
# Docker data if separate
docker_use=""
if df -P /var/lib/docker >/dev/null 2>&1; then
  docker_use="$(df -P /var/lib/docker | awk "NR==2 {gsub(/%/,\"\",\$5); print \$5}")"
fi
thresh="${DISK_ALERT_PCT:-90}"
fail=0
if [[ "$use" -ge "$thresh" ]]; then
  echo "ALERT: root disk ${use}% >= ${thresh}%"
  df -h / | tail -1
  fail=1
fi
if [[ -n "$docker_use" && "$docker_use" -ge "$thresh" ]]; then
  echo "ALERT: docker disk ${docker_use}% >= ${thresh}%"
  df -h /var/lib/docker | tail -1
  fail=1
fi
exit "$fail"
