#!/bin/bash
set -euo pipefail

# Only allow bounded Kafka identifiers; all shell expansions remain quoted.
topics=("${KAFKA_TOPIC_NOTIFICATIONS}" "${KAFKA_TOPIC_PAYMENTS}" "${KAFKA_TOPIC_NUTRITION}")
dlqs=("${KAFKA_TOPIC_NOTIFICATIONS_DLQ:-${topics[0]}.dlq}" "${KAFKA_TOPIC_PAYMENTS_DLQ:-${topics[1]}.dlq}" "${KAFKA_TOPIC_NUTRITION_DLQ:-${topics[2]}.dlq}")
for i in 0 1 2; do
  for kind in main dlq; do
    destination="${topics[$i]}"
    partitions=3
    if [[ "$kind" == dlq ]]; then destination="${dlqs[$i]}"; partitions=1; fi
    [[ "$destination" =~ ^[a-zA-Z0-9][a-zA-Z0-9._-]{0,239}$ ]] || { echo 'Invalid topic name' >&2; exit 1; }
    /opt/kafka/bin/kafka-topics.sh --bootstrap-server "$KAFKA_BOOTSTRAP_SERVERS" \
      --create --if-not-exists --topic "$destination" --partitions "$partitions" --replication-factor 1 \
      --config retention.ms=604800000 --config min.insync.replicas=1
  done
done
