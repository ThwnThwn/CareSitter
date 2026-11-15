using CareSitter.Contracts.Services;
using CareSitter.Modules.Booking.Application;
using CareSitter.Modules.Booking.Domain;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;

namespace CareSitter.Modules.Booking.Infrastructure;

/// <summary>Converts durable user reports into Support tickets with retry and leasing.</summary>
internal sealed class BookingChatReportDispatcher(
    BookingDbContext db,
    IBookingChatSupportTicketService tickets,
    IOptions<BookingChatOptions> options,
    ILogger<BookingChatReportDispatcher> logger)
{
    private readonly BookingChatOptions _options = options.Value;

    public async Task<int> DispatchPendingAsync(CancellationToken ct)
    {
        var now = DateTimeOffset.UtcNow;
        var claimed = await ClaimAsync(now, ct);
        foreach (var report in claimed)
        {
            var claimToken = report.ClaimToken
                ?? throw new InvalidOperationException("claimed_report_without_token");
            try
            {
                var context = await (from message in db.BookingChatMessages.AsNoTracking()
                                     join conversation in db.BookingChatConversations.AsNoTracking()
                                         on message.ConversationId equals conversation.Id
                                     where message.Id == report.MessageId
                                     select new { conversation.Id, conversation.BookingId })
                    .SingleOrDefaultAsync(ct);
                if (context is null)
                    throw new InvalidOperationException("reported_message_missing");
                var ticketId = await tickets.CreateForBookingChatReportAsync(new(
                    report.Id, report.ReporterUserId, context.BookingId, context.Id,
                    report.MessageId, report.Reason), ct);
                var linked = await TryLinkAsync(report.Id, claimToken, ticketId,
                    context.Id, DateTimeOffset.UtcNow, ct);
                if (!linked)
                    logger.LogInformation(
                        "Ignored stale booking chat report claim {ClaimToken} for {ReportId}.",
                        claimToken, report.Id);
            }
            catch (Exception exception) when (exception is not OperationCanceledException)
            {
                await MarkFailedAsync(report, claimToken, exception, ct);
            }
        }
        return claimed.Count;
    }

    private async Task<IReadOnlyList<BookingChatReport>> ClaimAsync(DateTimeOffset now,
        CancellationToken ct)
    {
        var leaseUntil = now.AddSeconds(Math.Max(5, _options.DispatcherLeaseSeconds));
        await using var tx = await db.Database.BeginTransactionAsync(ct);
        var reports = await db.BookingChatReports.FromSqlInterpolated($$"""
            SELECT * FROM booking.booking_chat_reports
            WHERE (status IN ('PENDING', 'FAILED') OR
                   (status = 'PROCESSING' AND lease_until IS NOT NULL AND lease_until <= {{now}}))
              AND available_at <= {{now}}
              AND (lease_until IS NULL OR lease_until <= {{now}})
            ORDER BY created_at, id
            LIMIT {{Math.Clamp(_options.DispatcherBatchSize, 1, 200)}}
            FOR UPDATE SKIP LOCKED
            """).AsNoTracking().ToListAsync(ct);
        foreach (var report in reports)
        {
            report.Claim(Guid.NewGuid(), now, leaseUntil);
            db.BookingChatReports.Update(report);
        }
        if (reports.Count > 0) await db.SaveChangesAsync(ct);
        await tx.CommitAsync(ct);
        foreach (var report in reports) db.Entry(report).State = EntityState.Detached;
        return reports;
    }

    private async Task<bool> TryLinkAsync(Guid reportId, Guid claimToken, Guid ticketId,
        Guid conversationId, DateTimeOffset now, CancellationToken ct)
    {
        await using var tx = await db.Database.BeginTransactionAsync(ct);
        var updated = await db.BookingChatReports
            .Where(x => x.Id == reportId && x.Status == "PROCESSING" &&
                        x.ClaimToken == claimToken)
            .ExecuteUpdateAsync(setters => setters
                .SetProperty(x => x.SupportTicketId, ticketId)
                .SetProperty(x => x.Status, "LINKED")
                .SetProperty(x => x.ClaimToken, (Guid?)null)
                .SetProperty(x => x.LeaseUntil, (DateTimeOffset?)null)
                .SetProperty(x => x.LastError, (string?)null)
                .SetProperty(x => x.UpdatedAt, now), ct);
        if (updated == 0)
        {
            await tx.RollbackAsync(ct);
            return false;
        }

        db.BookingChatActivityEvents.Add(BookingChatActivityEvent.Create(
            conversationId, null, "REPORT_LINKED", ticketId.ToString(), now));
        await db.SaveChangesAsync(ct);
        await tx.CommitAsync(ct);
        return true;
    }

    private async Task MarkFailedAsync(BookingChatReport report, Guid claimToken,
        Exception exception, CancellationToken ct)
    {
        var now = DateTimeOffset.UtcNow;
        var deadLetter = report.Attempts >= Math.Max(1, _options.DispatcherMaxAttempts);
        var error = exception.GetType().Name;
        var truncatedError = error.Length <= 500 ? error : error[..500];
        var availableAt = now.AddSeconds(
            Math.Max(1, _options.DispatcherRetryDelaySeconds));
        var updated = await db.BookingChatReports
            .Where(x => x.Id == report.Id && x.Status == "PROCESSING" &&
                        x.ClaimToken == claimToken)
            .ExecuteUpdateAsync(setters => setters
                .SetProperty(x => x.Status, deadLetter ? "DEAD_LETTER" : "FAILED")
                .SetProperty(x => x.ClaimToken, (Guid?)null)
                .SetProperty(x => x.LeaseUntil, (DateTimeOffset?)null)
                .SetProperty(x => x.AvailableAt, availableAt)
                .SetProperty(x => x.LastError, truncatedError)
                .SetProperty(x => x.UpdatedAt, now), ct);
        if (updated == 0)
        {
            logger.LogInformation(
                "Ignored failed stale booking chat report claim {ClaimToken} for {ReportId}.",
                claimToken, report.Id);
            return;
        }
        logger.LogWarning(exception, "Booking chat report {ReportId} ticket creation failed.", report.Id);
    }
}
