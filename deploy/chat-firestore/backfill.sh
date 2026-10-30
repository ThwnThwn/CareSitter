#!/bin/sh
set -eu

batch_size=${CHAT_FIRESTORE_BACKFILL_BATCH_SIZE:-200}
case "$batch_size" in
    ''|*[!0-9]*) echo 'Batch size must be an integer from 1 to 500.' >&2; exit 1 ;;
esac
[ "$batch_size" -ge 1 ] && [ "$batch_size" -le 500 ] || {
    echo 'Batch size must be an integer from 1 to 500.' >&2
    exit 1
}

total=0
while :; do
    added=$(psql -X -A -t -v ON_ERROR_STOP=1 \
        -c "SELECT public.enqueue_chat_firestore_backfill($batch_size)")
    case "$added" in
        ''|*[!0-9]*) echo 'Unexpected backfill result.' >&2; exit 1 ;;
    esac
    total=$((total + added))
    [ "$added" -eq 0 ] && break
done
echo "Enqueued $total historical chat messages."
