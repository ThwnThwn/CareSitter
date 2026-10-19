using CareSitter.Contracts.Services;
using CareSitter.Modules.Booking.Application;
using CareSitter.Modules.Booking.Domain;
using CareSitter.Modules.Booking.Infrastructure;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging.Abstractions;
using Microsoft.Extensions.Options;

namespace CareSitter.IntegrationTests;

public sealed partial class BookingChatPaginationTests
{
    [PostgresFact]
    public async Task ReportDispatcher_StaleLeaseOwner_CannotOverwriteNewOwner()
    {
        Guid reportId;
        Guid conversationId;
        var firstTicketId = Guid.NewGuid();
        var secondTicketId = Guid.NewGuid();
        await using (var seedDb = CreateDb())
        {
            var seed = await SeedConversationWithMessagesAsync(
                seedDb, messageCount: 1, jumbleTimestamps: false);
            conversationId = seed.ConversationId;
            var messageId = await seedDb.BookingChatMessages
                .Where(x => x.ConversationId == seed.ConversationId)
                .Select(x => x.Id)
                .SingleAsync();
            var report = BookingChatReport.Create(
                messageId, seed.CustomerId, "Nội dung không phù hợp", DateTimeOffset.UtcNow);
            reportId = report.Id;
            seedDb.BookingChatReports.Add(report);
            await seedDb.SaveChangesAsync();
            await seedDb.Database.ExecuteSqlInterpolatedAsync($$"""
                INSERT INTO support.support_tickets
                    (id, user_id, booking_id, type, priority, title, description)
                VALUES
                    ({{firstTicketId}}, {{seed.CustomerId}}, {{seed.BookingId}}, 'COMPLAINT', 'HIGH',
                     'Lease race first ticket', 'Ticket persisted by the fencing test fake.'),
                    ({{secondTicketId}}, {{seed.CustomerId}}, {{seed.BookingId}}, 'COMPLAINT', 'HIGH',
                     'Lease race second ticket', 'Ticket persisted by the fencing test fake.')
                """);
        }

        var tickets = new LeaseRaceTicketService(firstTicketId, secondTicketId);
        var options = Options.Create(new BookingChatOptions
        {
            DispatcherLeaseSeconds = 5,
            DispatcherBatchSize = 1,
            DispatcherMaxAttempts = 3,
            DispatcherRetryDelaySeconds = 1
        });

        await using var firstDb = CreateDb();
        await using var secondDb = CreateDb();
        var first = new BookingChatReportDispatcher(firstDb, tickets, options,
            NullLogger<BookingChatReportDispatcher>.Instance);
        var second = new BookingChatReportDispatcher(secondDb, tickets, options,
            NullLogger<BookingChatReportDispatcher>.Instance);

        var staleWorker = first.DispatchPendingAsync(CancellationToken.None);
        await tickets.FirstCallStarted.Task.WaitAsync(TimeSpan.FromSeconds(10));

        await secondDb.BookingChatReports
            .Where(x => x.Id == reportId)
            .ExecuteUpdateAsync(setters => setters
                .SetProperty(x => x.LeaseUntil, DateTimeOffset.UtcNow.AddSeconds(-1)));

        Assert.Equal(1, await second.DispatchPendingAsync(CancellationToken.None));
        tickets.ReleaseFirstCall.TrySetResult(true);
        Assert.Equal(1, await staleWorker);

        await using var assertDb = CreateDb();
        var finalReport = await assertDb.BookingChatReports.AsNoTracking()
            .SingleAsync(x => x.Id == reportId);
        Assert.True(finalReport.Status == "LINKED",
            $"Expected LINKED, got {finalReport.Status}; lastError={finalReport.LastError}");
        Assert.Equal(tickets.SecondTicketId, finalReport.SupportTicketId);
        Assert.Equal(1, await assertDb.BookingChatActivityEvents.CountAsync(x =>
            x.ConversationId == conversationId && x.Action == "REPORT_LINKED"));
    }

    private sealed class LeaseRaceTicketService(
        Guid firstTicketId,
        Guid secondTicketId) : IBookingChatSupportTicketService
    {
        private int _calls;

        public Guid FirstTicketId { get; } = firstTicketId;
        public Guid SecondTicketId { get; } = secondTicketId;
        public TaskCompletionSource<bool> FirstCallStarted { get; } =
            new(TaskCreationOptions.RunContinuationsAsynchronously);
        public TaskCompletionSource<bool> ReleaseFirstCall { get; } =
            new(TaskCreationOptions.RunContinuationsAsynchronously);

        public async Task<Guid> CreateForBookingChatReportAsync(
            BookingChatReportTicketRequest request, CancellationToken ct = default)
        {
            if (Interlocked.Increment(ref _calls) != 1)
                return SecondTicketId;

            FirstCallStarted.TrySetResult(true);
            await ReleaseFirstCall.Task.WaitAsync(ct);
            return FirstTicketId;
        }

        public Task<bool> AreResolvedAsync(IReadOnlyCollection<Guid> ticketIds,
            CancellationToken ct = default) => Task.FromResult(false);
    }
}
