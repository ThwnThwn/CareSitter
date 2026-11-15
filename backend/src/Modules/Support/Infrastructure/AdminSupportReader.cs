using CareSitter.Contracts.Services;
using CareSitter.Modules.Support.Domain;
using Microsoft.EntityFrameworkCore;

namespace CareSitter.Modules.Support.Infrastructure;

internal sealed class AdminSupportReader(SupportDbContext db) : IAdminSupportReader
{
    public async Task<AdminSupportSnapshot> GetDashboardSnapshotAsync(CancellationToken ct = default)
    {
        var openTickets = await db.SupportTickets.AsNoTracking()
            .CountAsync(x => x.Status == "NEW" || x.Status == "IN_PROGRESS", ct);
        var openDisputes = await db.Disputes.AsNoTracking()
            .CountAsync(x => x.Status == "OPEN" || x.Status == "INVESTIGATING", ct);

        var ticketItems = await db.SupportTickets.AsNoTracking()
            .Where(x => x.Status == "NEW" || x.Status == "IN_PROGRESS")
            .OrderByDescending(x => x.Priority == "CRITICAL")
            .ThenByDescending(x => x.Priority == "HIGH")
            .ThenBy(x => x.CreatedAt)
            .Take(5)
            .Select(x => new AdminQueueItem(
                "SUPPORT",
                x.Id,
                x.Title,
                x.Type + " · " + x.Priority,
                x.Status,
                x.CreatedAt) { Priority = x.Priority })
            .ToListAsync(ct);

        var disputeItems = await db.Disputes.AsNoTracking()
            .Where(x => x.Status == "OPEN" || x.Status == "INVESTIGATING")
            .OrderBy(x => x.OpenedAt)
            .Take(5)
            .Select(x => new
            {
                x.Id,
                x.BookingId,
                x.Reason,
                x.Status,
                x.OpenedAt
            })
            .ToListAsync(ct);

        var workItems = ticketItems.Concat(disputeItems.Select(x => new AdminQueueItem(
                "DISPUTE",
                x.Id,
                x.Reason ?? "Khiếu nại booking",
                $"Booking {x.BookingId}",
                x.Status,
                x.OpenedAt)))
            .ToArray();

        return new AdminSupportSnapshot(openTickets, openDisputes, workItems);
    }

    public IReadOnlyDictionary<string, string[]> GetTicketTransitions() =>
        new Dictionary<string, string[]>(StringComparer.OrdinalIgnoreCase)
        {
            ["NEW"] = SupportTicket.AllowedTransitions("NEW").ToArray(),
            ["IN_PROGRESS"] = SupportTicket.AllowedTransitions("IN_PROGRESS").ToArray(),
            ["RESOLVED"] = SupportTicket.AllowedTransitions("RESOLVED").ToArray(),
            ["CLOSED"] = SupportTicket.AllowedTransitions("CLOSED").ToArray()
        };
}
