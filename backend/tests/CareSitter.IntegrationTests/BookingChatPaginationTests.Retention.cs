using CareSitter.Modules.Booking.Domain;
using CareSitter.Modules.Booking.Infrastructure;
using Microsoft.EntityFrameworkCore;

namespace CareSitter.IntegrationTests;

public sealed partial class BookingChatPaginationTests
{
    [PostgresFact]
    public async Task Retention_dry_run_and_purge_respect_all_holds()
    {
        var now = DateTimeOffset.UtcNow;
        await using var db = CreateDb();
        var eligible = await SeedConversationWithMessagesAsync(db, 2, false);
        var legalHold = await SeedConversationWithMessagesAsync(db, 2, false);
        var pendingReport = await SeedConversationWithMessagesAsync(db, 2, false);
        var holdReason = "Purge test";
        var holdUntil = DateTimeOffset.MaxValue;

        await db.Database.ExecuteSqlInterpolatedAsync($"""
            UPDATE booking.booking_chat_conversations
            SET retained_until = {now.AddDays(-1)}
            WHERE id IN ({eligible.ConversationId}, {legalHold.ConversationId}, {pendingReport.ConversationId});
            UPDATE booking.booking_chat_conversations
            SET legal_hold_at = {now.AddDays(-2)}, legal_hold_reason = {holdReason},
                hold_until = {holdUntil}
            WHERE id = {legalHold.ConversationId};
            """);
        var reportMessageId = await db.BookingChatMessages.AsNoTracking()
            .Where(x => x.ConversationId == pendingReport.ConversationId)
            .Select(x => x.Id).FirstAsync();
        db.BookingChatReports.Add(BookingChatReport.Create(
            reportMessageId, pendingReport.CustomerId, "Chờ xử lý", now));
        await db.SaveChangesAsync();

        var retention = new BookingChatRetentionService(db);
        var preview = await retention.RunAsync(now, dryRun: true, batchSize: 100);
        Assert.Equal([eligible.ConversationId], preview.ConversationIds);
        Assert.Equal(2, await db.BookingChatMessages.CountAsync(
            x => x.ConversationId == eligible.ConversationId));

        var purged = await retention.RunAsync(now, dryRun: false, batchSize: 100);
        Assert.Equal([eligible.ConversationId], purged.ConversationIds);
        Assert.False(await db.BookingChatMessages.AnyAsync(
            x => x.ConversationId == eligible.ConversationId));
        Assert.True(await db.BookingChatMessages.AnyAsync(
            x => x.ConversationId == legalHold.ConversationId));
        Assert.True(await db.BookingChatMessages.AnyAsync(
            x => x.ConversationId == pendingReport.ConversationId));
    }
}
