using CareSitter.Messaging.Persistence.Outbox;
using Microsoft.EntityFrameworkCore;

namespace CareSitter.Messaging.Persistence.Inbox;

/// <summary>Maps inbox deduplication into the business owner's schema.</summary>
public static class InboxConfiguration
{
    /// <summary>Maps the composite consumer/handler/event key used for local transaction deduplication.</summary>
    public static ModelBuilder ApplyKafkaInbox(this ModelBuilder model, string schema)
    {
        OutboxConfiguration.ValidateSchema(schema);
        var b = model.Entity<InboxMessage>();
        b.ToTable("kafka_inbox_messages", schema);
        b.HasKey(x => new { x.ConsumerName, x.HandlerName, x.EventId });
        b.Property(x => x.ConsumerName).HasColumnName("consumer_name");
        b.Property(x => x.HandlerName).HasColumnName("handler_name");
        b.Property(x => x.EventId).HasColumnName("event_id");
        b.Property(x => x.EventType).HasColumnName("event_type");
        b.Property(x => x.ProcessedAt).HasColumnName("processed_at");
        return model;
    }
}
