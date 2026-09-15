using CareSitter.Modules.Support.Domain;
using Microsoft.EntityFrameworkCore;

namespace CareSitter.Modules.Support.Infrastructure;

internal sealed class SupportRepository(SupportDbContext db) : ISupportRepository
{
    public Task<bool> DisputeExistsAsync(Guid bookingId, CancellationToken ct = default) =>
        db.Disputes.AnyAsync(x => x.BookingId == bookingId, ct);

    public Task<Dispute?> GetDisputeAsync(Guid id, CancellationToken ct = default) =>
        db.Disputes.SingleOrDefaultAsync(x => x.Id == id, ct);

    public void AddDispute(Dispute dispute) => db.Disputes.Add(dispute);

    public Task<Notification?> GetNotificationAsync(
        Guid id, Guid userId, CancellationToken ct = default) =>
        db.Notifications.SingleOrDefaultAsync(x => x.Id == id && x.UserId == userId, ct);

    public Task<List<Notification>> GetUnreadNotificationsAsync(
        Guid userId, CancellationToken ct = default) =>
        db.Notifications.Where(x => x.UserId == userId && x.ReadAt == null).ToListAsync(ct);

    public void AddNotification(Notification notification) => db.Notifications.Add(notification);

    public Task<bool> ReviewExistsAsync(Guid bookingId, CancellationToken ct = default) =>
        db.Reviews.AnyAsync(x => x.BookingId == bookingId, ct);

    public async Task<bool> TryAddReviewAsync(Review review, CancellationToken ct = default)
    {
        db.Reviews.Add(review);
        try
        {
            await db.SaveChangesAsync(ct);
            return true;
        }
        catch (DbUpdateException)
        {
            // Preserve the legacy controller behavior: every update failure maps to duplicate.
            return false;
        }
    }

    public Task<SupportTicket?> GetSupportTicketAsync(Guid id, CancellationToken ct = default) =>
        db.SupportTickets.SingleOrDefaultAsync(x => x.Id == id, ct);

    public void AddSupportTicket(SupportTicket ticket) => db.SupportTickets.Add(ticket);

    public Task SaveChangesAsync(CancellationToken ct = default) => db.SaveChangesAsync(ct);
}
