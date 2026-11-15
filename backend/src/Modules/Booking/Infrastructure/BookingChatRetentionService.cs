using CareSitter.Modules.Booking.Domain;
using Microsoft.EntityFrameworkCore;

namespace CareSitter.Modules.Booking.Infrastructure;

internal sealed record BookingChatRetentionResult(IReadOnlyList<Guid> ConversationIds);

internal sealed class BookingChatRetentionService(BookingDbContext db)
{
    private static readonly string[] UnresolvedReportStatuses =
        ["PENDING", "PROCESSING", "FAILED", "DEAD_LETTER"];
    private static readonly string[] UnresolvedOutboxStatuses =
        ["PENDING", "PROCESSING", "FAILED", "DEAD_LETTER"];

    public async Task<BookingChatRetentionResult> RunAsync(
        DateTimeOffset now, bool dryRun, int batchSize, CancellationToken ct = default)
    {
        var size = Math.Clamp(batchSize, 1, 200);
        var candidateIds = await Eligible(now).OrderBy(x => x.RetainedUntil)
            .ThenBy(x => x.Id).Select(x => x.Id).Take(size).ToListAsync(ct);
        if (dryRun || candidateIds.Count == 0)
            return new BookingChatRetentionResult(candidateIds);

        var purged = new List<Guid>(candidateIds.Count);
        foreach (var conversationId in candidateIds)
        {
            await using var tx = await db.Database.BeginTransactionAsync(ct);
            var bookingId = await db.BookingChatConversations.AsNoTracking()
                .Where(x => x.Id == conversationId)
                .Select(x => (Guid?)x.BookingId).SingleOrDefaultAsync(ct);
            if (bookingId is null)
            {
                await tx.RollbackAsync(ct);
                continue;
            }

            _ = await db.Bookings.FromSqlInterpolated(
                $"SELECT * FROM booking.bookings WHERE id = {bookingId.Value} FOR UPDATE")
                .SingleOrDefaultAsync(ct);
            var conversation = await db.BookingChatConversations.FromSqlInterpolated(
                $"SELECT * FROM booking.booking_chat_conversations WHERE id = {conversationId} FOR UPDATE")
                .SingleOrDefaultAsync(ct);
            if (conversation is null || !await IsEligibleAsync(conversation, now, ct))
            {
                await tx.RollbackAsync(ct);
                db.ChangeTracker.Clear();
                continue;
            }

            await db.BookingChatReadCursors.Where(x => x.ConversationId == conversationId)
                .ExecuteDeleteAsync(ct);
            await db.BookingChatOutbox.Where(x => x.ConversationId == conversationId)
                .ExecuteDeleteAsync(ct);
            await db.BookingChatMessages.Where(x => x.ConversationId == conversationId)
                .ExecuteDeleteAsync(ct);
            await db.BookingChatEpochs.Where(x => x.ConversationId == conversationId)
                .ExecuteDeleteAsync(ct);
            conversation.MarkPurged(now);
            db.BookingChatActivityEvents.Add(BookingChatActivityEvent.Create(
                conversationId, null, "CONTENT_PURGED", "Retention policy", now));
            await db.SaveChangesAsync(ct);
            await tx.CommitAsync(ct);
            purged.Add(conversationId);
            db.ChangeTracker.Clear();
        }

        return new BookingChatRetentionResult(purged);
    }

    private IQueryable<BookingChatConversation> Eligible(DateTimeOffset now) =>
        db.BookingChatConversations.AsNoTracking().Where(conversation =>
            conversation.PurgedAt == null &&
            conversation.RetainedUntil != null && conversation.RetainedUntil <= now &&
            conversation.DisputeLockedAt == null &&
            (conversation.LegalHoldAt == null || conversation.LegalHoldReleasedAt != null) &&
            (conversation.HoldUntil == null || conversation.HoldUntil <= now) &&
            !db.BookingChatReports.Any(report =>
                UnresolvedReportStatuses.Contains(report.Status) &&
                db.BookingChatMessages.Any(message => message.Id == report.MessageId &&
                    message.ConversationId == conversation.Id)) &&
            !db.BookingChatOutbox.Any(outbox => outbox.ConversationId == conversation.Id &&
                UnresolvedOutboxStatuses.Contains(outbox.Status)));

    private async Task<bool> IsEligibleAsync(
        BookingChatConversation conversation, DateTimeOffset now, CancellationToken ct)
    {
        var unresolvedReport = await db.BookingChatReports.AnyAsync(report =>
            UnresolvedReportStatuses.Contains(report.Status) &&
            db.BookingChatMessages.Any(message => message.Id == report.MessageId &&
                message.ConversationId == conversation.Id), ct);
        var unresolvedOutbox = await db.BookingChatOutbox.AnyAsync(outbox =>
            outbox.ConversationId == conversation.Id &&
            UnresolvedOutboxStatuses.Contains(outbox.Status), ct);
        return BookingChatRetentionPolicy.CanPurge(
            conversation, now, unresolvedReport, unresolvedOutbox);
    }
}
