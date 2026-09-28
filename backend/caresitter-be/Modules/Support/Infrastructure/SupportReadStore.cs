using CareSitter.Modules.Support.Application;
using Microsoft.EntityFrameworkCore;

namespace CareSitter.Modules.Support.Infrastructure;

internal sealed class SupportReadStore(SupportDbContext db) : ISupportReadStore
{
    public async Task<SupportPage<DisputeResponse>> ListDisputesAsync(
        string? status, int page, int pageSize, CancellationToken ct = default)
    {
        var query = db.Disputes.AsNoTracking().AsQueryable();
        if (!string.IsNullOrWhiteSpace(status))
        {
            var normalized = status.Trim().ToUpperInvariant();
            query = query.Where(x => x.Status == normalized);
        }

        var total = await query.CountAsync(ct);
        var entities = await query.OrderByDescending(x => x.OpenedAt)
            .Skip((page - 1) * pageSize).Take(pageSize).ToListAsync(ct);
        return new SupportPage<DisputeResponse>(
            entities.Select(SupportResponseMapper.ToResponse).ToArray(), total, page, pageSize);
    }

    public async Task<DisputeResponse?> GetDisputeAsync(Guid disputeId, CancellationToken ct = default)
    {
        var dispute = await db.Disputes.AsNoTracking().SingleOrDefaultAsync(x => x.Id == disputeId, ct);
        return dispute is null ? null : SupportResponseMapper.ToResponse(dispute);
    }

    public async Task<IReadOnlyList<DisputeResponse>> ListUserDisputesAsync(
        Guid userId, CancellationToken ct = default)
    {
        var disputes = await db.Disputes.AsNoTracking()
            .Where(x => x.RaisedByUserId == userId)
            .OrderByDescending(x => x.OpenedAt)
            .ToListAsync(ct);
        return disputes.Select(SupportResponseMapper.ToResponse).ToArray();
    }

    public async Task<DisputeResponse?> GetUserDisputeAsync(
        Guid disputeId, Guid userId, CancellationToken ct = default)
    {
        var dispute = await db.Disputes.AsNoTracking()
            .SingleOrDefaultAsync(x => x.Id == disputeId && x.RaisedByUserId == userId, ct);
        return dispute is null ? null : SupportResponseMapper.ToResponse(dispute);
    }

    public async Task<SupportPage<NotificationResponse>> ListNotificationsAsync(
        Guid userId, int page, int pageSize, CancellationToken ct = default)
    {
        var query = db.Notifications.AsNoTracking().Where(x => x.UserId == userId);
        var total = await query.CountAsync(ct);
        var entities = await query.OrderByDescending(x => x.CreatedAt)
            .Skip((page - 1) * pageSize).Take(pageSize).ToListAsync(ct);
        return new SupportPage<NotificationResponse>(
            entities.Select(SupportResponseMapper.ToResponse).ToArray(), total, page, pageSize);
    }

    public Task<int> CountUnreadNotificationsAsync(Guid userId, CancellationToken ct = default) =>
        db.Notifications.CountAsync(x => x.UserId == userId && x.ReadAt == null, ct);

    public async Task<SupportPage<ReviewResponse>> ListCaregiverReviewsAsync(
        Guid caregiverId, int page, int pageSize, CancellationToken ct = default)
    {
        var query = db.Reviews.AsNoTracking().Where(x => x.CaregiverId == caregiverId);
        var total = await query.CountAsync(ct);
        var entities = await query.OrderByDescending(x => x.CreatedAt)
            .Skip((page - 1) * pageSize).Take(pageSize).ToListAsync(ct);
        return new SupportPage<ReviewResponse>(
            entities.Select(SupportResponseMapper.ToResponse).ToArray(), total, page, pageSize);
    }

    public async Task<SupportPage<SupportTicketResponse>> ListTicketsAsync(
        Guid userId, bool isAdmin, string? status, string? type, string? priority,
        int page, int pageSize, CancellationToken ct = default)
    {
        var query = db.SupportTickets.AsNoTracking().AsQueryable();
        if (!isAdmin) query = query.Where(x => x.UserId == userId);
        if (!string.IsNullOrWhiteSpace(status))
        {
            var normalized = status.ToUpperInvariant();
            query = query.Where(x => x.Status == normalized);
        }
        if (!string.IsNullOrWhiteSpace(type))
        {
            var normalized = type.ToUpperInvariant();
            query = query.Where(x => x.Type == normalized);
        }
        if (!string.IsNullOrWhiteSpace(priority))
        {
            var normalized = priority.ToUpperInvariant();
            query = query.Where(x => x.Priority == normalized);
        }

        var total = await query.CountAsync(ct);
        var entities = await query.OrderByDescending(x => x.CreatedAt)
            .Skip((page - 1) * pageSize).Take(pageSize).ToListAsync(ct);
        return new SupportPage<SupportTicketResponse>(
            entities.Select(SupportResponseMapper.ToResponse).ToArray(), total, page, pageSize);
    }

    public async Task<SupportTicketResponse?> GetTicketAsync(Guid ticketId, CancellationToken ct = default)
    {
        var ticket = await db.SupportTickets.AsNoTracking()
            .SingleOrDefaultAsync(x => x.Id == ticketId, ct);
        return ticket is null ? null : SupportResponseMapper.ToResponse(ticket);
    }
}
