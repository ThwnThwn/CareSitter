#!/bin/sh
# Shared helpers for host-side operations scripts. Source after setting -eu.
# Never source this file with shell tracing (set -x) enabled: ops.env holds secrets.
umask 077

: "${repo_dir:?Set repo_dir to the repository root before sourcing common.sh}"
releases_dir="$repo_dir/deploy/.releases"

log() { printf '%s %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$*"; }
fail() { log "ERROR: $*" >&2; exit 1; }
require_command() { command -v "$1" >/dev/null 2>&1 || fail "Missing required command: $1"; }

app_compose() { sh "$repo_dir/deploy/app-compose.sh" "$@"; }

# Read KEY=value lines without evaluating them as shell code.
env_value() {
    file=$1; key=$2
    [ -f "$file" ] || return 0
    sed -n "s/^$key=//p" "$file" | tail -n 1
}

load_ops_env() {
    ops_env="$repo_dir/deploy/ops.env"
    for key in BACKUP_DIRECTORY BACKUP_RECIPIENT_FILE BACKUP_RETENTION_DAYS BACKUP_RCLONE_REMOTE \
        BACKUP_MAX_AGE_HOURS ALERT_WEBHOOK_URL ALERT_ENVIRONMENT_LABEL DISK_ALERT_PERCENT \
        TLS_MIN_DAYS HEALTH_URL KEEP_RELEASE_IMAGES; do
        current=$(eval "printf '%s' \"\${$key:-}\"")
        if [ -z "$current" ]; then
            value=$(env_value "$ops_env" "$key")
            [ -z "$value" ] || export "$key=$value"
        fi
    done
    BACKUP_DIRECTORY=${BACKUP_DIRECTORY:-/var/backups/caresitter}
    BACKUP_RETENTION_DAYS=${BACKUP_RETENTION_DAYS:-14}
    BACKUP_MAX_AGE_HOURS=${BACKUP_MAX_AGE_HOURS:-26}
    DISK_ALERT_PERCENT=${DISK_ALERT_PERCENT:-85}
    TLS_MIN_DAYS=${TLS_MIN_DAYS:-14}
    KEEP_RELEASE_IMAGES=${KEEP_RELEASE_IMAGES:-5}
    app_domain=$(env_value "$repo_dir/deploy/.env" APP_DOMAIN)
    HEALTH_URL=${HEALTH_URL:-"https://$app_domain/health/ready"}
}

# Slack reads "text", Discord reads "content"; send both so either webhook works.
send_alert() {
    message="[CareSitter ${ALERT_ENVIRONMENT_LABEL:-$(hostname)}] $1"
    log "ALERT: $message"
    [ -n "${ALERT_WEBHOOK_URL:-}" ] || return 0
    escaped=$(printf '%s' "$message" | sed 's/\\/\\\\/g; s/"/\\"/g' | tr '\n' ' ')
    curl -fsS --max-time 10 -H 'Content-Type: application/json' \
        -d "{\"text\":\"$escaped\",\"content\":\"$escaped\"}" "$ALERT_WEBHOOK_URL" >/dev/null ||
        log 'WARNING: alert webhook delivery failed.' >&2
}

wait_for_ready() {
    attempts=${1:-40}
    i=0
    while [ "$i" -lt "$attempts" ]; do
        if curl -fsS --max-time 5 "$HEALTH_URL" 2>/dev/null | grep -q '"status":"Healthy"'; then
            return 0
        fi
        i=$((i + 1))
        sleep 3
    done
    return 1
}
