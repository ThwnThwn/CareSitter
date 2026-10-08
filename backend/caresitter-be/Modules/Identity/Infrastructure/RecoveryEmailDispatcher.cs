using CareSitter.Contracts.Services;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;

namespace CareSitter.Modules.Identity.Infrastructure;

internal sealed class RecoveryEmailDispatcher(IdentityDbContext db, RecoverySecrets secrets,
    IEmailSender sender, IClock clock, ILogger<RecoveryEmailDispatcher> logger)
{
    public async Task<bool> DispatchOnceAsync(CancellationToken ct)
    {
        RecoveryEmailRecord? item;
        var now = clock.UtcNow;
        await using (var tx = await db.Database.BeginTransactionAsync(ct))
        {
            item = await db.RecoveryEmails.FromSqlInterpolated($"""
                SELECT * FROM identity.recovery_email_outbox
                WHERE completed_at IS NULL AND next_attempt_at <= {now}
                  AND (lease_until IS NULL OR lease_until <= {now})
                ORDER BY created_at LIMIT 1 FOR UPDATE SKIP LOCKED
                """).SingleOrDefaultAsync(ct);
            if (item is null) return false;
            item.LeaseId = Guid.NewGuid(); item.LeaseUntil = now.AddMinutes(2); item.Attempts++;
            await db.SaveChangesAsync(ct); await tx.CommitAsync(ct);
        }
        var success = false;
        var outcome = "SKIPPED";
        try
        {
            var live = item.ExpiresAt > clock.UtcNow;
            if (live && item.ChallengeId is { } challengeId)
                live = await db.RecoveryChallenges.AsNoTracking().AnyAsync(x => x.Id == challengeId &&
                    x.ConsumedAt == null && x.CodeConsumedAt == null && x.ExpiresAt > clock.UtcNow, ct);
            if (live && item.Payload is not null)
            {
                var mail = secrets.Decrypt(item.Payload);
                if (mail.Recipient is not null)
                {
                    using var timeout = CancellationTokenSource.CreateLinkedTokenSource(ct);
                    timeout.CancelAfter(TimeSpan.FromSeconds(30));
                    await sender.SendAsync(mail.Recipient, mail.Subject, mail.Html, timeout.Token);
                    outcome = "SENT";
                }
            }
            success = true;
        }
        catch (OperationCanceledException) when (ct.IsCancellationRequested) { throw; }
        catch (Exception)
        {
            outcome = "FAILED";
            // Không ghi exception SMTP: thông báo lỗi provider có thể chứa địa chỉ/mã.
            logger.LogWarning("Recovery email delivery failed for outbox {OutboxId}, attempt {Attempt}.", item.Id, item.Attempts);
        }
        var terminal = success || item.Attempts >= 5 || item.ExpiresAt <= clock.UtcNow;
        var next = clock.UtcNow.AddSeconds(Math.Min(300, 15 * Math.Pow(2, item.Attempts - 1)));
        await db.RecoveryEmails.Where(x => x.Id == item.Id && x.LeaseId == item.LeaseId && x.CompletedAt == null)
            .ExecuteUpdateAsync(s => s.SetProperty(x => x.CompletedAt, terminal ? clock.UtcNow : (DateTimeOffset?)null)
                .SetProperty(x => x.Status, terminal ? outcome : "PENDING")
                .SetProperty(x => x.Payload, terminal ? null : item.Payload)
                .SetProperty(x => x.LeaseUntil, (DateTimeOffset?)null)
                .SetProperty(x => x.LeaseId, (Guid?)null)
                .SetProperty(x => x.NextAttemptAt, next), ct);
        if (!success && terminal) logger.LogError("Recovery email outbox {OutboxId} exhausted retries or expired.", item.Id);
        return true;
    }

    public async Task PurgeAsync(int retentionDays, CancellationToken ct)
    {
        var cutoff = clock.UtcNow.AddDays(-retentionDays);
        await db.RecoveryEmails.Where(x => x.CompletedAt < cutoff).ExecuteDeleteAsync(ct);
        await db.RecoveryChallenges.Where(x => x.ExpiresAt < cutoff).ExecuteDeleteAsync(ct);
    }
}

internal sealed class RecoveryEmailWorker(IServiceScopeFactory scopes, IOptions<RecoveryOptions> options,
    ILogger<RecoveryEmailWorker> logger) : BackgroundService
{
    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        if (!options.Value.Enabled) return;
        var nextCleanup = DateTimeOffset.MinValue;
        while (!stoppingToken.IsCancellationRequested)
        {
            try
            {
                if (DateTimeOffset.UtcNow >= nextCleanup)
                {
                    await using var cleanupScope = scopes.CreateAsyncScope();
                    await cleanupScope.ServiceProvider.GetRequiredService<RecoveryEmailDispatcher>()
                        .PurgeAsync(options.Value.MetadataRetentionDays, stoppingToken);
                    nextCleanup = DateTimeOffset.UtcNow.AddHours(1);
                }
                for (var i = 0; i < 10; i++)
                {
                    await using var scope = scopes.CreateAsyncScope();
                    if (!await scope.ServiceProvider.GetRequiredService<RecoveryEmailDispatcher>().DispatchOnceAsync(stoppingToken)) break;
                }
            }
            catch (OperationCanceledException) when (stoppingToken.IsCancellationRequested) { break; }
            catch (Exception) { logger.LogError("Recovery email worker unavailable; it will retry."); }
            try { await Task.Delay(TimeSpan.FromSeconds(2), stoppingToken); }
            catch (OperationCanceledException) when (stoppingToken.IsCancellationRequested) { break; }
        }
    }
}
