using CareSitter.Infrastructure.Persistence;
using CareSitter.Contracts.Services;
using CareSitter.Modules.Support.Domain;
using Microsoft.EntityFrameworkCore;
using CareSitter.Messaging.Persistence.Outbox;

namespace CareSitter.Modules.Support.Infrastructure;

/// <summary>DbContext module Support — schema "support" (disputes, support_tickets, reviews, notifications).</summary>
public sealed class SupportDbContext : ModuleDbContext
{
    public const string SchemaName = "support";

    public SupportDbContext(DbContextOptions<SupportDbContext> options, ICurrentUser? currentUser = null)
        : base(options, currentUser) { }

    protected override string Schema => SchemaName;

    public DbSet<Dispute> Disputes => Set<Dispute>();
    public DbSet<SupportTicket> SupportTickets => Set<SupportTicket>();
    public DbSet<Review> Reviews => Set<Review>();
    public DbSet<Notification> Notifications => Set<Notification>();
    public DbSet<ChatConversation> ChatConversations => Set<ChatConversation>();
    public DbSet<ChatMessage> ChatMessages => Set<ChatMessage>();
    public DbSet<ChatReadCursor> ChatReadCursors => Set<ChatReadCursor>();
    public DbSet<ChatActivityEvent> ChatActivityEvents => Set<ChatActivityEvent>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        base.OnModelCreating(modelBuilder);
        modelBuilder.ApplyConfiguration(new ConsultationRequestConfiguration());
        modelBuilder.ApplyKafkaOutbox(SchemaName);
        modelBuilder.Entity<ChatConversation>(b =>
        {
            b.ToTable("chat_conversations", SchemaName);
            b.HasKey(x => x.Id);
            b.Property(x => x.Id).HasColumnName("id");
            b.Property(x => x.TicketId).HasColumnName("ticket_id");
            b.Property(x => x.OwnerUserId).HasColumnName("owner_user_id");
            b.Property(x => x.CreateKey).HasColumnName("create_key");
            b.Property(x => x.CreatePayloadHash).HasColumnName("create_payload_hash").HasMaxLength(64);
            b.Property(x => x.LastSequence).HasColumnName("last_sequence");
            b.Property(x => x.StaffLastReadSequence).HasColumnName("staff_last_read_sequence");
            b.Property(x => x.Version).HasColumnName("version");
            b.Property(x => x.LastMessageAt).HasColumnName("last_message_at");
            b.Property(x => x.ClosedAt).HasColumnName("closed_at");
            b.Property(x => x.CreatedAt).HasColumnName("created_at");
            b.Property(x => x.UpdatedAt).HasColumnName("updated_at");
            b.HasOne<SupportTicket>().WithOne().HasForeignKey<ChatConversation>(x => x.TicketId)
                .OnDelete(DeleteBehavior.Restrict);
            b.HasIndex(x => x.TicketId).IsUnique();
            b.HasIndex(x => new { x.OwnerUserId, x.CreateKey }).IsUnique();
        });
        modelBuilder.Entity<ChatMessage>(b =>
        {
            b.ToTable("chat_messages", SchemaName);
            b.HasKey(x => x.Id);
            b.Property(x => x.Id).HasColumnName("id");
            b.Property(x => x.ConversationId).HasColumnName("conversation_id");
            b.Property(x => x.Sequence).HasColumnName("sequence");
            b.Property(x => x.SenderUserId).HasColumnName("sender_user_id");
            b.Property(x => x.SenderRole).HasColumnName("sender_role");
            b.Property(x => x.IdempotencyKey).HasColumnName("idempotency_key");
            b.Property(x => x.Body).HasColumnName("body");
            b.Property(x => x.PayloadHash).HasColumnName("payload_hash");
            b.Property(x => x.CreatedAt).HasColumnName("created_at");
            b.HasOne<ChatConversation>().WithMany().HasForeignKey(x => x.ConversationId)
                .OnDelete(DeleteBehavior.Restrict);
            b.HasIndex(x => new { x.ConversationId, x.Sequence }).IsUnique();
            b.HasIndex(x => new { x.ConversationId, x.SenderUserId, x.IdempotencyKey }).IsUnique();
        });
        modelBuilder.Entity<ChatReadCursor>(b =>
        {
            b.ToTable("chat_read_cursors", SchemaName);
            b.HasKey(x => new { x.ConversationId, x.UserId });
            b.Property(x => x.ConversationId).HasColumnName("conversation_id");
            b.Property(x => x.UserId).HasColumnName("user_id");
            b.Property(x => x.LastReadSequence).HasColumnName("last_read_sequence");
            b.Property(x => x.UpdatedAt).HasColumnName("updated_at");
            b.HasOne<ChatConversation>().WithMany().HasForeignKey(x => x.ConversationId)
                .OnDelete(DeleteBehavior.Restrict);
        });
        modelBuilder.Entity<ChatActivityEvent>(b =>
        {
            b.ToTable("chat_activity_events", SchemaName);
            b.HasKey(x => x.Id);
            b.Property(x => x.Id).HasColumnName("id");
            b.Property(x => x.ConversationId).HasColumnName("conversation_id");
            b.Property(x => x.ActorUserId).HasColumnName("actor_user_id");
            b.Property(x => x.Action).HasColumnName("action");
            b.Property(x => x.FromStatus).HasColumnName("from_status");
            b.Property(x => x.ToStatus).HasColumnName("to_status");
            b.Property(x => x.FromAdminId).HasColumnName("from_admin_id");
            b.Property(x => x.ToAdminId).HasColumnName("to_admin_id");
            b.Property(x => x.Reason).HasColumnName("reason");
            b.Property(x => x.CreatedAt).HasColumnName("created_at");
            b.HasOne<ChatConversation>().WithMany().HasForeignKey(x => x.ConversationId)
                .OnDelete(DeleteBehavior.Restrict);
        });
        modelBuilder.Entity<NotificationDelivery>(b =>
        {
            b.ToTable("notification_deliveries", SchemaName);
            b.HasKey(x => new { x.EventId, x.Channel });
            b.Property(x => x.EventId).HasColumnName("event_id");
            b.Property(x => x.Channel).HasColumnName("channel");
            b.Property(x => x.NotificationId).HasColumnName("notification_id");
            b.Property(x => x.Status).HasColumnName("status");
            b.Property(x => x.ClaimToken).HasColumnName("claim_token");
            b.Property(x => x.LeaseUntil).HasColumnName("lease_until");
            b.Property(x => x.SentAt).HasColumnName("sent_at");
            b.Property(x => x.LastError).HasColumnName("last_error");
            b.HasOne<Notification>().WithMany().HasForeignKey(x => x.NotificationId).OnDelete(DeleteBehavior.Cascade);
        });

        modelBuilder.Entity<Dispute>(b =>
        {
            b.ToTable("disputes");
            b.HasKey(x => x.Id);
            b.Property(x => x.Id).HasColumnName("id");
            b.Property(x => x.BookingId).HasColumnName("booking_id");
            b.Property(x => x.RaisedByUserId).HasColumnName("raised_by_user_id");
            b.Property(x => x.Reason).HasColumnName("reason").HasMaxLength(255);
            b.Property(x => x.Description).HasColumnName("description");
            b.Property(x => x.Status).HasColumnName("status").HasMaxLength(20);
            b.Property(x => x.Evidence).HasColumnName("evidence").HasColumnType("jsonb");
            b.Property(x => x.Decision).HasColumnName("decision").HasMaxLength(20);
            b.Property(x => x.RefundAmount).HasColumnName("refund_amount");
            b.Property(x => x.CaregiverPenaltyAmount).HasColumnName("caregiver_penalty_amount");
            b.Property(x => x.DecidedByAdminId).HasColumnName("decided_by_admin_id");
            b.Property(x => x.OpenedAt).HasColumnName("opened_at");
            b.Property(x => x.ResolvedAt).HasColumnName("resolved_at");
            // Bang disputes khong co created_at/updated_at — opened_at la thoi diem mien nghiep vu.
            b.Ignore(x => x.CreatedAt);
            b.Ignore(x => x.UpdatedAt);
            b.Ignore(x => x.DomainEvents);
        });

        modelBuilder.Entity<SupportTicket>(b =>
        {
            b.ToTable("support_tickets");
            b.HasKey(x => x.Id);
            b.Property(x => x.Id).HasColumnName("id");
            b.Property(x => x.UserId).HasColumnName("user_id");
            b.Property(x => x.BookingId).HasColumnName("booking_id");
            b.Property(x => x.Type).HasColumnName("type").HasMaxLength(20);
            b.Property(x => x.Status).HasColumnName("status").HasMaxLength(20);
            b.Property(x => x.Priority).HasColumnName("priority").HasMaxLength(20);
            b.Property(x => x.Title).HasColumnName("title").HasMaxLength(255);
            b.Property(x => x.Description).HasColumnName("description");
            b.Property(x => x.AttachmentUrls).HasColumnName("attachment_urls").HasColumnType("jsonb");
            b.Property(x => x.AssignedAdminId).HasColumnName("assigned_admin_id");
            b.Property(x => x.Version).HasColumnName("version");
            b.Property(x => x.CreatedAt).HasColumnName("created_at");
            b.Property(x => x.UpdatedAt).HasColumnName("updated_at");
            b.Ignore(x => x.DomainEvents);
        });

        modelBuilder.Entity<Review>(b =>
        {
            b.ToTable("reviews");
            b.HasKey(x => x.Id);
            b.Property(x => x.Id).HasColumnName("id");
            b.Property(x => x.BookingId).HasColumnName("booking_id");
            b.Property(x => x.CaregiverId).HasColumnName("caregiver_id");
            b.Property(x => x.CustomerId).HasColumnName("customer_id");
            b.Property(x => x.Rating).HasColumnName("rating");
            b.Property(x => x.Comment).HasColumnName("comment");
            b.Property(x => x.ExperienceTags).HasColumnName("experience_tags").HasColumnType("jsonb");
            b.Property(x => x.CreatedAt).HasColumnName("created_at");
            // Bang reviews khong co updated_at.
            b.Ignore(x => x.UpdatedAt);
        });

        modelBuilder.Entity<Notification>(b =>
        {
            b.ToTable("notifications");
            b.HasKey(x => x.Id);
            b.Property(x => x.Id).HasColumnName("id");
            b.Property(x => x.UserId).HasColumnName("user_id");
            b.Property(x => x.Type).HasColumnName("type").HasMaxLength(20);
            b.Property(x => x.Title).HasColumnName("title").HasMaxLength(255);
            b.Property(x => x.Body).HasColumnName("body");
            b.Property(x => x.Data).HasColumnName("data").HasColumnType("jsonb");
            b.Property(x => x.ReadAt).HasColumnName("read_at");
            b.Property(x => x.ChatMessageId).HasColumnName("chat_message_id");
            b.HasOne<ChatMessage>().WithMany().HasForeignKey(x => x.ChatMessageId)
                .OnDelete(DeleteBehavior.Restrict);
            b.Property(x => x.CreatedAt).HasColumnName("created_at");
            // Bang notifications khong co updated_at.
            b.Ignore(x => x.UpdatedAt);
        });
    }
}
