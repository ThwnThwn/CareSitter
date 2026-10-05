using CareSitter.Contracts.Services;
using CareSitter.Modules.Support.Application.Commands;
using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Support.Application;

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
