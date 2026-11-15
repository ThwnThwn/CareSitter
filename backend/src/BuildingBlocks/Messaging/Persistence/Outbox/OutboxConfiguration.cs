using System.Text.RegularExpressions;
using CareSitter.Messaging.Persistence.Inbox;
using Microsoft.EntityFrameworkCore;

namespace CareSitter.Messaging.Persistence.Outbox;

/// <summary>Maps reusable messaging entities into the owning module's PostgreSQL schema.</summary>
public static class OutboxConfiguration
{
    /// <summary>Maps the outbox; runtime schema changes remain managed by init-db SQL.</summary>
    public static ModelBuilder ApplyKafkaOutbox(this ModelBuilder model, string schema)
    {
        ValidateSchema(schema);
        var b = model.Entity<KafkaOutboxMessage>();
        b.ToTable("kafka_outbox_messages", schema);
        b.HasKey(x => x.Id);
        b.Property(x => x.Id).HasColumnName("id");
        b.Property(x => x.EventType).HasColumnName("event_type");
        b.Property(x => x.SchemaVersion).HasColumnName("schema_version");
        b.Property(x => x.Topic).HasColumnName("topic");
        b.Property(x => x.MessageKey).HasColumnName("message_key");
        b.Property(x => x.Envelope).HasColumnName("envelope").HasColumnType("jsonb");
        b.Property(x => x.CorrelationId).HasColumnName("correlation_id");
        b.Property(x => x.OccurredAt).HasColumnName("occurred_at");
        b.Property(x => x.PublishedAt).HasColumnName("published_at");
        b.Property(x => x.AttemptCount).HasColumnName("attempt_count");
        b.Property(x => x.NextAttemptAt).HasColumnName("next_attempt_at");
        b.Property(x => x.LastError).HasColumnName("last_error");
        b.Property(x => x.LeaseOwner).HasColumnName("lease_owner");
        b.Property(x => x.LeaseUntil).HasColumnName("lease_until");
        b.HasIndex(x => new { x.NextAttemptAt, x.OccurredAt }).HasFilter("published_at IS NULL")
            .HasDatabaseName("ix_kafka_outbox_pending");
        return model;
    }

    /// <summary>Restricts identifiers before they are used in provider-specific claim SQL.</summary>
    public static void ValidateSchema(string schema)
    {
        if (!Regex.IsMatch(schema, "^[a-z][a-z0-9_]{0,62}$")) throw new ArgumentException("Invalid messaging schema.", nameof(schema));
    }
}
