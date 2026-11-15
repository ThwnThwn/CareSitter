using CareSitter.Contracts.Services;
using CareSitter.Modules.Support.Application.Commands;
using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Support.Application;

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
