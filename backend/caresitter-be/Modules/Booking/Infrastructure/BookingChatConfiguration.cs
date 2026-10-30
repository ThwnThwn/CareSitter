using CareSitter.Modules.Booking.Domain;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace CareSitter.Modules.Booking.Infrastructure;

internal sealed class BookingChatConversationConfiguration
    : IEntityTypeConfiguration<BookingChatConversation>
{
    public void Configure(EntityTypeBuilder<BookingChatConversation> b)
    {
        b.ToTable("booking_chat_conversations", BookingDbContext.SchemaName);
        b.HasKey(x => x.Id);
        b.Property(x => x.Id).HasColumnName("id");
        b.Property(x => x.BookingId).HasColumnName("booking_id");
        b.Property(x => x.LastSequence).HasColumnName("last_sequence");
        b.Property(x => x.ChangeVersion).HasColumnName("change_version");
        b.Property(x => x.ScopeVersion).HasColumnName("scope_version");
        b.Property(x => x.LastMessageAt).HasColumnName("last_message_at");
        b.Property(x => x.GraceStartedAt).HasColumnName("grace_started_at");
        b.Property(x => x.WriteClosesAt).HasColumnName("write_closes_at");
        b.Property(x => x.DisputeLockedAt).HasColumnName("dispute_locked_at");
        b.Property(x => x.WriteBlockedAt).HasColumnName("write_blocked_at");
        b.Property(x => x.WriteBlockReason).HasColumnName("write_block_reason").HasMaxLength(500);
        b.Property(x => x.BlockedByUserId).HasColumnName("blocked_by_user_id");
        b.Property(x => x.RetainedUntil).HasColumnName("retained_until");
        b.Property(x => x.HoldUntil).HasColumnName("hold_until");
        b.Property(x => x.LegalHoldAt).HasColumnName("legal_hold_at");
        b.Property(x => x.LegalHoldReason).HasColumnName("legal_hold_reason").HasMaxLength(500);
        b.Property(x => x.LegalHoldReleasedAt).HasColumnName("legal_hold_released_at");
        b.Property(x => x.PurgedAt).HasColumnName("purged_at");
        b.Property(x => x.CreatedAt).HasColumnName("created_at");
        b.Property(x => x.UpdatedAt).HasColumnName("updated_at");
        b.HasOne<Domain.Booking>().WithOne().HasForeignKey<BookingChatConversation>(x => x.BookingId)
            .OnDelete(DeleteBehavior.Cascade);
        b.HasIndex(x => x.BookingId).IsUnique().HasDatabaseName("uq_booking_chat_booking");
    }
}

internal sealed class BookingChatActivityEventConfiguration
    : IEntityTypeConfiguration<BookingChatActivityEvent>
{
    public void Configure(EntityTypeBuilder<BookingChatActivityEvent> b)
    {
        b.ToTable("booking_chat_activity_events", BookingDbContext.SchemaName);
        b.HasKey(x => x.Id);
        b.Property(x => x.Id).HasColumnName("id");
        b.Property(x => x.ConversationId).HasColumnName("conversation_id");
        b.Property(x => x.ActorUserId).HasColumnName("actor_user_id");
        b.Property(x => x.Action).HasColumnName("action").HasMaxLength(40);
        b.Property(x => x.Reason).HasColumnName("reason").HasMaxLength(500);
        b.Property(x => x.CreatedAt).HasColumnName("created_at");
    }
}

internal sealed class BookingChatReportConfiguration : IEntityTypeConfiguration<BookingChatReport>
{
    public void Configure(EntityTypeBuilder<BookingChatReport> b)
    {
        b.ToTable("booking_chat_reports", BookingDbContext.SchemaName);
        b.HasKey(x => x.Id);
        b.Property(x => x.Id).HasColumnName("id");
        b.Property(x => x.MessageId).HasColumnName("message_id");
        b.Property(x => x.ReporterUserId).HasColumnName("reporter_user_id");
        b.Property(x => x.Reason).HasColumnName("reason").HasMaxLength(500);
        b.Property(x => x.SupportTicketId).HasColumnName("support_ticket_id");
        b.Property(x => x.Status).HasColumnName("status").HasMaxLength(20);
        b.Property(x => x.Attempts).HasColumnName("attempts");
        b.Property(x => x.AvailableAt).HasColumnName("available_at");
        b.Property(x => x.LeaseUntil).HasColumnName("lease_until");
        b.Property(x => x.ClaimToken).HasColumnName("claim_token");
        b.Property(x => x.LastError).HasColumnName("last_error").HasMaxLength(500);
        b.Property(x => x.CreatedAt).HasColumnName("created_at");
        b.Property(x => x.UpdatedAt).HasColumnName("updated_at");
        b.HasIndex(x => new { x.MessageId, x.ReporterUserId }).IsUnique()
            .HasDatabaseName("uq_booking_chat_report");
    }
}

internal sealed class BookingChatUserBlockConfiguration
    : IEntityTypeConfiguration<BookingChatUserBlock>
{
    public void Configure(EntityTypeBuilder<BookingChatUserBlock> b)
    {
        b.ToTable("booking_chat_user_blocks", BookingDbContext.SchemaName);
        b.HasKey(x => new { x.ConversationId, x.BlockerUserId, x.BlockedUserId });
        b.Property(x => x.ConversationId).HasColumnName("conversation_id");
        b.Property(x => x.BlockerUserId).HasColumnName("blocker_user_id");
        b.Property(x => x.BlockedUserId).HasColumnName("blocked_user_id");
        b.Property(x => x.BlockedAt).HasColumnName("blocked_at");
        b.Property(x => x.UnblockedAt).HasColumnName("unblocked_at");
        b.HasOne<BookingChatConversation>().WithMany()
            .HasForeignKey(x => x.ConversationId).OnDelete(DeleteBehavior.Cascade);
        b.HasIndex(x => new { x.ConversationId, x.BlockedUserId })
            .HasFilter("unblocked_at IS NULL")
            .HasDatabaseName("ix_booking_chat_user_blocks_active_target");
    }
}

internal sealed class BookingChatEpochConfiguration : IEntityTypeConfiguration<BookingChatEpoch>
{
    public void Configure(EntityTypeBuilder<BookingChatEpoch> b)
    {
        b.ToTable("booking_chat_epochs", BookingDbContext.SchemaName);
        b.HasKey(x => x.Id);
        b.Property(x => x.Id).HasColumnName("id");
        b.Property(x => x.ConversationId).HasColumnName("conversation_id");
        b.Property(x => x.EpochNumber).HasColumnName("epoch_number");
        b.Property(x => x.CaregiverProfileId).HasColumnName("caregiver_profile_id");
        b.Property(x => x.CaregiverUserId).HasColumnName("caregiver_user_id");
        b.Property(x => x.StartedAt).HasColumnName("started_at");
        b.Property(x => x.EndedAt).HasColumnName("ended_at");
        b.HasOne<BookingChatConversation>().WithMany().HasForeignKey(x => x.ConversationId)
            .OnDelete(DeleteBehavior.Cascade);
        b.HasIndex(x => new { x.ConversationId, x.EpochNumber }).IsUnique()
            .HasDatabaseName("uq_booking_chat_epoch_number");
    }
}

internal sealed class BookingChatMessageConfiguration : IEntityTypeConfiguration<BookingChatMessage>
{
    public void Configure(EntityTypeBuilder<BookingChatMessage> b)
    {
        b.ToTable("booking_chat_messages", BookingDbContext.SchemaName);
        b.HasKey(x => x.Id);
        b.Property(x => x.Id).HasColumnName("id");
        b.Property(x => x.ConversationId).HasColumnName("conversation_id");
        b.Property(x => x.EpochId).HasColumnName("epoch_id");
        b.Property(x => x.Sequence).HasColumnName("sequence");
        b.Property(x => x.SenderUserId).HasColumnName("sender_user_id");
        b.Property(x => x.SenderRole).HasColumnName("sender_role").HasMaxLength(20);
        b.Property(x => x.Kind).HasColumnName("kind").HasMaxLength(20);
        b.Property(x => x.TemplateKey).HasColumnName("template_key").HasMaxLength(100);
        b.Property(x => x.TemplateVersion).HasColumnName("template_version");
        b.Property(x => x.TemplateParams).HasColumnName("template_params").HasColumnType("jsonb");
        b.Property(x => x.BodySnapshot).HasColumnName("body_snapshot").HasMaxLength(2000);
        b.Property(x => x.IdempotencyKey).HasColumnName("idempotency_key");
        b.Property(x => x.PayloadHash).HasColumnName("payload_hash").HasMaxLength(64);
        b.Property(x => x.SourceEventId).HasColumnName("source_event_id");
        b.Property(x => x.CreatedAt).HasColumnName("created_at");
        b.HasOne<BookingChatConversation>().WithMany().HasForeignKey(x => x.ConversationId)
            .OnDelete(DeleteBehavior.Cascade);
        b.HasOne<BookingChatEpoch>().WithMany().HasForeignKey(x => x.EpochId)
            .OnDelete(DeleteBehavior.Restrict);
        b.HasIndex(x => new { x.ConversationId, x.Sequence }).IsUnique()
            .HasDatabaseName("uq_booking_chat_message_sequence");
    }
}

internal sealed class BookingChatOutboxConfiguration : IEntityTypeConfiguration<BookingChatOutboxEvent>
{
    public void Configure(EntityTypeBuilder<BookingChatOutboxEvent> b)
    {
        b.ToTable("booking_chat_outbox", BookingDbContext.SchemaName);
        b.HasKey(x => x.EventId);
        b.Property(x => x.EventId).HasColumnName("event_id");
        b.Property(x => x.ConversationId).HasColumnName("conversation_id");
        b.Property(x => x.EpochId).HasColumnName("epoch_id");
        b.Property(x => x.RecipientUserId).HasColumnName("recipient_user_id");
        b.Property(x => x.Kind).HasColumnName("kind").HasMaxLength(40);
        b.Property(x => x.ChangeVersion).HasColumnName("change_version");
        b.Property(x => x.MessageId).HasColumnName("message_id");
        b.Property(x => x.Status).HasColumnName("status").HasMaxLength(20);
        b.Property(x => x.Attempts).HasColumnName("attempts");
        b.Property(x => x.AvailableAt).HasColumnName("available_at");
        b.Property(x => x.LeaseUntil).HasColumnName("lease_until");
        b.Property(x => x.LastError).HasColumnName("last_error").HasMaxLength(500);
        b.Property(x => x.CreatedAt).HasColumnName("created_at");
        b.Property(x => x.UpdatedAt).HasColumnName("updated_at");
        b.HasOne<BookingChatConversation>().WithMany().HasForeignKey(x => x.ConversationId)
            .OnDelete(DeleteBehavior.Cascade);
        b.HasOne<BookingChatEpoch>().WithMany().HasForeignKey(x => x.EpochId)
            .OnDelete(DeleteBehavior.Cascade);
        b.HasOne<BookingChatMessage>().WithMany().HasForeignKey(x => x.MessageId)
            .OnDelete(DeleteBehavior.Cascade);
    }
}

internal sealed class BookingChatReadCursorConfiguration
    : IEntityTypeConfiguration<BookingChatReadCursor>
{
    public void Configure(EntityTypeBuilder<BookingChatReadCursor> b)
    {
        b.ToTable("booking_chat_read_cursors", BookingDbContext.SchemaName);
        b.HasKey(x => new { x.ConversationId, x.EpochId, x.UserId });
        b.Property(x => x.ConversationId).HasColumnName("conversation_id");
        b.Property(x => x.EpochId).HasColumnName("epoch_id");
        b.Property(x => x.UserId).HasColumnName("user_id");
        b.Property(x => x.LastReadSequence).HasColumnName("last_read_sequence");
        b.Property(x => x.UpdatedAt).HasColumnName("updated_at");
        b.HasOne<BookingChatConversation>().WithMany().HasForeignKey(x => x.ConversationId)
            .OnDelete(DeleteBehavior.Cascade);
        b.HasOne<BookingChatEpoch>().WithMany().HasForeignKey(x => x.EpochId)
            .OnDelete(DeleteBehavior.Cascade);
    }
}
