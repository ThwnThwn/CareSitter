using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Support.Application;

public sealed record SupportPage<T>(IReadOnlyList<T> Items, int Total, int Page, int PageSize);
public sealed record UnreadNotificationCountResponse(int Unread);

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

    Task<SupportPage<SupportTicketResponse>> ListTicketsAsync(
        Guid userId, bool isAdmin, string? status, string? type, string? priority,
        int page, int pageSize, CancellationToken ct = default);
    Task<SupportTicketResponse?> GetTicketAsync(Guid ticketId, CancellationToken ct = default);
}

public sealed record ListAdminDisputesQuery(
    string? Status, int Page, int PageSize) : IRequest<Result<SupportPage<DisputeResponse>>>;
public sealed record GetAdminDisputeQuery(Guid DisputeId) : IRequest<Result<DisputeResponse>>;
public sealed record ListMyDisputesQuery : IRequest<Result<IReadOnlyList<DisputeResponse>>>;
public sealed record GetMyDisputeQuery(Guid DisputeId) : IRequest<Result<DisputeResponse>>;
public sealed record ListNotificationsQuery(
    int Page, int PageSize) : IRequest<Result<SupportPage<NotificationResponse>>>;
public sealed record GetUnreadNotificationCountQuery : IRequest<Result<UnreadNotificationCountResponse>>;
public sealed record ListCaregiverReviewsQuery(
    Guid CaregiverId, int Page, int PageSize) : IRequest<SupportPage<ReviewResponse>>;
public sealed record ListSupportTicketsQuery(
    string? Status, string? Type, string? Priority, int Page, int PageSize)
    : IRequest<Result<SupportPage<SupportTicketResponse>>>;
public sealed record GetSupportTicketQuery(Guid TicketId) : IRequest<Result<SupportTicketResponse>>;
