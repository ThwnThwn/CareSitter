#!/bin/sh
# Host-side health probe, run every 5 minutes by caresitter-healthcheck.timer.
# Alerts once when something breaks and once when it recovers (no spam).
# This watches the VM from the inside; ALSO configure an external uptime
# monitor on HEALTH_URL, because this script cannot alert if the VM is down.
set -eu
repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
. "$repo_dir/deploy/ops/common.sh"
for command in docker curl openssl df; do require_command "$command"; done
load_ops_env
mkdir -p "$releases_dir"
state_file="$releases_dir/health-state"

problems=''
add_problem() { problems="${problems:+$problems; }$1"; }

# 1. Public readiness through Caddy (DB + Redis checks included).
body=$(curl -sS --max-time 10 "$HEALTH_URL" 2>&1 || true)
printf '%s' "$body" | grep -q '"status":"Healthy"' || add_problem "readiness not Healthy at $HEALTH_URL"

# 2. Long-running containers.
running=$(app_compose ps --status running --services 2>/dev/null || true)
for service in db redis api admin proxy; do
    printf '%s\n' "$running" | grep -qx "$service" || add_problem "container $service is not running"
done

# 3. Disk space on the Docker data root and the backup directory.
for path in /var/lib/docker "$BACKUP_DIRECTORY"; do
    [ -d "$path" ] || continue
    used=$(df -P "$path" | awk 'NR==2 { sub("%", "", $5); print $5 }')
    [ "$used" -lt "$DISK_ALERT_PERCENT" ] || add_problem "disk ${used}% used at $path"
done

# 4. Backup freshness.
if [ -f "$BACKUP_DIRECTORY/.last-success" ]; then
    age_hours=$(( ($(date -u +%s) - $(cat "$BACKUP_DIRECTORY/.last-success")) / 3600 ))
    [ "$age_hours" -lt "$BACKUP_MAX_AGE_HOURS" ] || add_problem "last successful backup is ${age_hours}h old"
else
    add_problem 'no successful backup recorded yet'
fi

# 5. TLS certificate expiry (Caddy renews automatically; this catches failures).
domain=$(printf '%s' "$HEALTH_URL" | sed -E 's#^https://([^/:]+).*#\1#')
if ! echo | openssl s_client -servername "$domain" -connect "$domain:443" 2>/dev/null |
    openssl x509 -noout -checkend $((TLS_MIN_DAYS * 86400)) >/dev/null 2>&1; then
    add_problem "TLS certificate for $domain expires within ${TLS_MIN_DAYS} days or is unreadable"
fi

previous_state=$(cat "$state_file" 2>/dev/null || echo ok)
if [ -n "$problems" ]; then
    # Re-alert only when the set of problems changes.
    if [ "$previous_state" != "$problems" ]; then
        send_alert "UNHEALTHY: $problems"
        printf '%s' "$problems" > "$state_file"
    fi
    exit 1
fi
if [ "$previous_state" != ok ]; then
    send_alert 'RECOVERED: all checks pass.'
    echo ok > "$state_file"
fi
