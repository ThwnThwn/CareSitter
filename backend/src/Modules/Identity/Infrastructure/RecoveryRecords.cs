using Microsoft.EntityFrameworkCore;

namespace CareSitter.Modules.Identity.Infrastructure;

internal sealed class RecoveryChallengeRecord
{
    public Guid Id { get; set; }
    public Guid? UserId { get; set; }
    public string Purpose { get; set; } = "RESET";
    public string Email { get; set; } = string.Empty;
    public string TargetEmail { get; set; } = string.Empty;
    public string RateKey { get; set; } = string.Empty;
    public long RecoveryVersion { get; set; }
    public string CodeHash { get; set; } = string.Empty;
    public int Attempts { get; set; }
    public DateTimeOffset CreatedAt { get; set; }
    public DateTimeOffset ExpiresAt { get; set; }
    public DateTimeOffset? CodeConsumedAt { get; set; }
    public string? GrantHash { get; set; }
    public DateTimeOffset? GrantExpiresAt { get; set; }
    public DateTimeOffset? ConsumedAt { get; set; }
}

internal sealed class RecoveryEmailRecord
{
    public Guid Id { get; set; }
    public Guid? ChallengeId { get; set; }
    public string? Payload { get; set; }
    public DateTimeOffset CreatedAt { get; set; }
    public DateTimeOffset ExpiresAt { get; set; }
    public DateTimeOffset NextAttemptAt { get; set; }
    public int Attempts { get; set; }
    public DateTimeOffset? LeaseUntil { get; set; }
    public Guid? LeaseId { get; set; }
    public DateTimeOffset? CompletedAt { get; set; }
    public string Status { get; set; } = "PENDING";
}

internal static class RecoveryRecords
{
    public static void Configure(ModelBuilder model)
    {
        model.Entity<RecoveryChallengeRecord>(b =>
        {
            b.ToTable("recovery_challenges"); b.HasKey(x => x.Id);
            b.Property(x => x.Id).HasColumnName("id");
            b.Property(x => x.UserId).HasColumnName("user_id");
            b.Property(x => x.Purpose).HasColumnName("purpose");
            b.Property(x => x.Email).HasColumnName("email");
            b.Property(x => x.TargetEmail).HasColumnName("target_email");
            b.Property(x => x.RateKey).HasColumnName("rate_key");
            b.Property(x => x.RecoveryVersion).HasColumnName("recovery_version");
            b.Property(x => x.CodeHash).HasColumnName("code_hash");
            b.Property(x => x.Attempts).HasColumnName("attempts");
            b.Property(x => x.CreatedAt).HasColumnName("created_at");
            b.Property(x => x.ExpiresAt).HasColumnName("expires_at");
            b.Property(x => x.CodeConsumedAt).HasColumnName("code_consumed_at");
            b.Property(x => x.GrantHash).HasColumnName("grant_hash");
            b.Property(x => x.GrantExpiresAt).HasColumnName("grant_expires_at");
            b.Property(x => x.ConsumedAt).HasColumnName("consumed_at");
            b.HasIndex(x => x.GrantHash).IsUnique().HasFilter("grant_hash IS NOT NULL");
            b.HasIndex(x => new { x.RateKey, x.CreatedAt });
        });
        model.Entity<RecoveryEmailRecord>(b =>
        {
            b.ToTable("recovery_email_outbox"); b.HasKey(x => x.Id);
            b.Property(x => x.Id).HasColumnName("id");
            b.Property(x => x.ChallengeId).HasColumnName("challenge_id");
            b.Property(x => x.Payload).HasColumnName("payload");
            b.Property(x => x.CreatedAt).HasColumnName("created_at");
            b.Property(x => x.ExpiresAt).HasColumnName("expires_at");
            b.Property(x => x.NextAttemptAt).HasColumnName("next_attempt_at");
            b.Property(x => x.Attempts).HasColumnName("attempts");
            b.Property(x => x.LeaseUntil).HasColumnName("lease_until");
            b.Property(x => x.LeaseId).HasColumnName("lease_id");
            b.Property(x => x.CompletedAt).HasColumnName("completed_at");
            b.Property(x => x.Status).HasColumnName("status");
        });
    }
}
