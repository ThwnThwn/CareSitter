#!/bin/sh
# Single entry point for Compose on a deployed VM. It pins RELEASE_TAG to the
# release recorded by deploy.sh/rollback.sh, so a manual `up -d` never swaps in
# an untagged image, and it adds the Nutrition overlay when ops.env enables it.
#   sh deploy/app-compose.sh ps
#   sh deploy/app-compose.sh logs -f --tail=200 api
set -eu
repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)

if [ -z "${RELEASE_TAG:-}" ] && [ -f "$repo_dir/deploy/.releases/current" ]; then
    RELEASE_TAG=$(cut -c1-12 "$repo_dir/deploy/.releases/current")
fi
export RELEASE_TAG="${RELEASE_TAG:-local}"

overlay=${CARESITTER_COMPOSE_OVERLAY:-}
if [ -z "$overlay" ] && [ -f "$repo_dir/deploy/ops.env" ]; then
    overlay=$(sed -n 's/^CARESITTER_COMPOSE_OVERLAY=//p' "$repo_dir/deploy/ops.env" | tail -n 1)
fi

case "$overlay" in
    ''|none)
        exec docker compose --project-directory "$repo_dir/deploy" -f "$repo_dir/deploy/compose.yml" "$@"
        ;;
    nutrition)
        exec sh "$repo_dir/deploy/nutrition/compose.sh" "$@"
        ;;
    *)
        echo "Unknown CARESITTER_COMPOSE_OVERLAY: $overlay" >&2
        exit 1
        ;;
esac
