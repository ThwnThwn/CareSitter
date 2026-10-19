using CareSitter.Contracts.Services;
using CareSitter.Modules.Support.Domain;
using Microsoft.EntityFrameworkCore;

namespace CareSitter.Modules.Support.Infrastructure;

/// <summary>
/// Support owns ticket creation. A transaction-scoped advisory lock makes retries of
/// one Booking report return the original ticket rather than creating a duplicate.
/// </summary>
internal sealed class BookingChatSupportTicketService(SupportDbContext db)
    : IBookingChatSupportTicketService
{
    public async Task<bool> AreResolvedAsync(
        IReadOnlyCollection<Guid> ticketIds, CancellationToken ct = default)
    {
        if (ticketIds.Count == 0) return true;
        var distinctIds = ticketIds.Distinct().ToArray();
        var resolvedCount = await db.SupportTickets.AsNoTracking()
            .CountAsync(ticket => distinctIds.Contains(ticket.Id) &&
                (ticket.Status == "RESOLVED" || ticket.Status == "CLOSED"), ct);
        return resolvedCount == distinctIds.Length;
    }

    public async Task<Guid> CreateForBookingChatReportAsync(
        BookingChatReportTicketRequest request, CancellationToken ct = default)
    {
        await using var tx = await db.Database.BeginTransactionAsync(ct);
        await db.Database.ExecuteSqlInterpolatedAsync(
            $"SELECT pg_advisory_xact_lock(hashtextextended({request.ReportId.ToString()}, 0))", ct);
        var existing = await db.Set<BookingChatReportTicketSource>()
            .SingleOrDefaultAsync(x => x.ReportId == request.ReportId, ct);
        if (existing is not null)
        {
            await tx.CommitAsync(ct);
            return existing.TicketId;
        }

        var ticket = SupportTicket.Create(request.ReporterUserId, "COMPLAINT", "HIGH",
            request.BookingId, "Báo cáo tin nhắn theo lịch chăm sóc",
            $"Report={request.ReportId}; Conversation={request.ConversationId}; " +
            $"Message={request.MessageId}; Reason={request.Reason}", "[]");
        if (ticket.IsFailure)
            throw new InvalidOperationException(ticket.Error.Code);
        db.SupportTickets.Add(ticket.Value);
        // The source row only carries scalar IDs, so EF cannot infer the FK insert
        // order. Persist the ticket first while keeping both writes atomic in this
        // transaction, then create the idempotency mapping.
        await db.SaveChangesAsync(ct);
        db.Set<BookingChatReportTicketSource>().Add(new BookingChatReportTicketSource(
            request.ReportId, ticket.Value.Id, DateTimeOffset.UtcNow));
        await db.SaveChangesAsync(ct);
        await tx.CommitAsync(ct);
        return ticket.Value.Id;
    }
}
