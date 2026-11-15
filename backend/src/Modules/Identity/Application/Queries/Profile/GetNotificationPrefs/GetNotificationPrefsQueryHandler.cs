using CareSitter.Contracts.Services;
using CareSitter.Modules.Identity.Application.UpdateProfile;
using CareSitter.Modules.Identity.Domain;
using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Identity.Application;

internal sealed class GetNotificationPrefsQueryHandler(IIdentityStore store, ICurrentUser currentUser)
    : IRequestHandler<GetNotificationPrefsQuery, Result<NotificationPrefs>>
{
    public async Task<Result<NotificationPrefs>> Handle(
        GetNotificationPrefsQuery request, CancellationToken ct)
    {
        if (currentUser.UserId is not { } userId) return IdentityManagementErrors.Unauthenticated();
        var user = await store.FindUserByIdAsync(userId, ct);
        return user is null ? IdentityManagementErrors.UserNotFound()
            : NotificationPrefs.Parse(user.NotificationPrefs);
    }
}
