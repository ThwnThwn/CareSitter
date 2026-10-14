#!/bin/sh
# Shared by one-shot deployment jobs; never source this file with shell tracing enabled.
set -eu
umask 077

fail() { echo "$1" >&2; exit 1; }
require_command() { command -v "$1" >/dev/null 2>&1 || fail "Missing required command: $1"; }
read_secret() {
    [ -f "$1" ] && [ -r "$1" ] || fail 'A required secret file is missing or unreadable.'
    secret_value=$(cat "$1")
    [ -n "$secret_value" ] || fail 'A required secret file is empty.'
    printf '%s' "$secret_value"
}
connect_nutrition_database() {
    [ "${PGDATABASE:-}" = nutrition ] || fail 'This job only operates on the nutrition database.'
    [ -n "${PGHOST:-}" ] && [ -n "${PGUSER:-}" ] || fail 'Set PGHOST and PGUSER explicitly.'
    PGPASSWORD=$(read_secret "${PGPASSWORD_FILE:?Set PGPASSWORD_FILE}")
    export PGPASSWORD
    PGCONNECT_TIMEOUT=10
    export PGCONNECT_TIMEOUT
}
create_work_directory() {
    work_dir=$(mktemp -d "${TMPDIR:-/tmp}/caresitter-nutrition.XXXXXXXX")
}
cleanup_work_directory() {
    [ -n "${work_dir:-}" ] || return 0
    case "${work_dir##*/}" in caresitter-nutrition.*) ;; *) return 1 ;; esac
    # All jobs create only regular files directly inside their own mktemp directory.
    rm -f -- "$work_dir"/*
    rmdir -- "$work_dir"
}
