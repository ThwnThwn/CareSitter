using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Support.Application;

public interface ISupportReadStore
{
    Task<SupportPage<DisputeResponse>> ListDisputesAsync(
        string? status, int page, int pageSize, CancellationToken ct = default);
    Task<DisputeResponse?> GetDisputeAsync(Guid disputeId, CancellationToken ct = default);
    Task<IReadOnlyList<DisputeResponse>> ListUserDisputesAsync(
        Guid userId, CancellationToken ct = default);
    Task<DisputeResponse?> GetUserDisputeAsync(
        Guid disputeId, Guid userId, CancellationToken ct = default);

    Task<SupportPage<NotificationResponse>> ListNotificationsAsync(
        Guid userId, int page, int pageSize, CancellationToken ct = default);
    Task<int> CountUnreadNotificationsAsync(Guid userId, CancellationToken ct = default);

    Task<SupportPage<ReviewResponse>> ListCaregiverReviewsAsync(
        Guid caregiverId, int page, int pageSize, CancellationToken ct = default);
    Task<ReviewResponse?> GetReviewByBookingAsync(Guid bookingId, CancellationToken ct = default);

    Task<SupportPage<SupportTicketResponse>> ListTicketsAsync(
        Guid userId, bool isAdmin, string? status, string? type, string? priority,
        int page, int pageSize, CancellationToken ct = default);
    Task<SupportTicketResponse?> GetTicketAsync(Guid ticketId, CancellationToken ct = default);
}
