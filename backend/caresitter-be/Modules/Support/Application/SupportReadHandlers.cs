using CareSitter.Contracts.Services;
using CareSitter.Modules.Support.Application.Commands;
using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Support.Application;

internal sealed class ListAdminDisputesQueryHandler(
    ISupportReadStore store,
    ICurrentUser currentUser) : IRequestHandler<ListAdminDisputesQuery, Result<SupportPage<DisputeResponse>>>
{
    public async Task<Result<SupportPage<DisputeResponse>>> Handle(
        ListAdminDisputesQuery request, CancellationToken ct)
    {
        if (!currentUser.IsInRole("ADMIN")) return SupportErrors.Forbidden();
        return await store.ListDisputesAsync(request.Status, Math.Max(request.Page, 1),
            Math.Clamp(request.PageSize, 1, 50), ct);
    }
}

internal sealed class GetAdminDisputeQueryHandler(
    ISupportReadStore store,
    ICurrentUser currentUser) : IRequestHandler<GetAdminDisputeQuery, Result<DisputeResponse>>
{
    public async Task<Result<DisputeResponse>> Handle(GetAdminDisputeQuery request, CancellationToken ct)
    {
        if (!currentUser.IsInRole("ADMIN")) return SupportErrors.Forbidden();
        var dispute = await store.GetDisputeAsync(request.DisputeId, ct);
        return dispute is null ? SupportErrors.NotFound() : dispute;
    }
}

internal sealed class ListMyDisputesQueryHandler(
    ISupportReadStore store,
    ICurrentUser currentUser) : IRequestHandler<ListMyDisputesQuery, Result<IReadOnlyList<DisputeResponse>>>
{
    public async Task<Result<IReadOnlyList<DisputeResponse>>> Handle(
        ListMyDisputesQuery request, CancellationToken ct)
    {
        if (currentUser.UserId is not { } userId) return SupportErrors.Unauthenticated();
        return Result.Success<IReadOnlyList<DisputeResponse>>(
            await store.ListUserDisputesAsync(userId, ct));
    }
}

internal sealed class GetMyDisputeQueryHandler(
    ISupportReadStore store,
    ICurrentUser currentUser) : IRequestHandler<GetMyDisputeQuery, Result<DisputeResponse>>
{
    public async Task<Result<DisputeResponse>> Handle(GetMyDisputeQuery request, CancellationToken ct)
    {
        if (currentUser.UserId is not { } userId) return SupportErrors.Unauthenticated();
        var dispute = await store.GetUserDisputeAsync(request.DisputeId, userId, ct);
        return dispute is null ? SupportErrors.NotFound() : dispute;
    }
}

internal sealed class ListNotificationsQueryHandler(
    ISupportReadStore store,
    ICurrentUser currentUser) : IRequestHandler<ListNotificationsQuery, Result<SupportPage<NotificationResponse>>>
{
    public async Task<Result<SupportPage<NotificationResponse>>> Handle(
        ListNotificationsQuery request, CancellationToken ct)
    {
        if (currentUser.UserId is not { } userId) return SupportErrors.Unauthenticated();
        return await store.ListNotificationsAsync(userId, Math.Max(request.Page, 1),
            Math.Clamp(request.PageSize, 1, 50), ct);
    }
}

internal sealed class GetUnreadNotificationCountQueryHandler(
    ISupportReadStore store,
    ICurrentUser currentUser) : IRequestHandler<GetUnreadNotificationCountQuery, Result<UnreadNotificationCountResponse>>
{
    public async Task<Result<UnreadNotificationCountResponse>> Handle(
        GetUnreadNotificationCountQuery request, CancellationToken ct)
    {
        if (currentUser.UserId is not { } userId) return SupportErrors.Unauthenticated();
        return new UnreadNotificationCountResponse(
            await store.CountUnreadNotificationsAsync(userId, ct));
    }
}

internal sealed class ListCaregiverReviewsQueryHandler(
    ISupportReadStore store) : IRequestHandler<ListCaregiverReviewsQuery, SupportPage<ReviewResponse>>
{
    public Task<SupportPage<ReviewResponse>> Handle(ListCaregiverReviewsQuery request, CancellationToken ct) =>
        store.ListCaregiverReviewsAsync(request.CaregiverId, Math.Max(request.Page, 1),
            Math.Clamp(request.PageSize, 1, 50), ct);
}

internal sealed class ListSupportTicketsQueryHandler(
    ISupportReadStore store,
    ICurrentUser currentUser) : IRequestHandler<ListSupportTicketsQuery, Result<SupportPage<SupportTicketResponse>>>
{
    public async Task<Result<SupportPage<SupportTicketResponse>>> Handle(
        ListSupportTicketsQuery request, CancellationToken ct)
    {
        if (currentUser.UserId is not { } userId) return SupportErrors.Unauthenticated();
        return await store.ListTicketsAsync(userId, currentUser.IsInRole("ADMIN"),
            request.Status, request.Type, request.Priority, Math.Max(request.Page, 1),
            Math.Clamp(request.PageSize, 1, 50), ct);
    }
}

internal sealed class GetSupportTicketQueryHandler(
    ISupportReadStore store,
    ICurrentUser currentUser) : IRequestHandler<GetSupportTicketQuery, Result<SupportTicketResponse>>
{
    public async Task<Result<SupportTicketResponse>> Handle(GetSupportTicketQuery request, CancellationToken ct)
    {
        if (currentUser.UserId is not { } userId) return SupportErrors.Unauthenticated();
        var ticket = await store.GetTicketAsync(request.TicketId, ct);
        if (ticket is null) return SupportErrors.NotFound();
        if (!currentUser.IsInRole("ADMIN") && ticket.UserId != userId) return SupportErrors.Forbidden();
        return ticket;
    }
}
