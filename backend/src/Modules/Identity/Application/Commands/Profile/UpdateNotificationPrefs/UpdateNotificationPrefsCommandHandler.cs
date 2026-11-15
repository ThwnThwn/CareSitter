using CareSitter.Contracts.Services;
using CareSitter.Modules.Identity.Application.UpdateProfile;
using CareSitter.Modules.Identity.Domain;
using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Identity.Application;

internal sealed class UpdateNotificationPrefsCommandHandler(
    IIdentityStore store, ICurrentUser currentUser)
    : IRequestHandler<UpdateNotificationPrefsCommand, Result<NotificationPrefs>>
{
    public async Task<Result<NotificationPrefs>> Handle(
        UpdateNotificationPrefsCommand request, CancellationToken ct)
    {
        if (currentUser.UserId is not { } userId) return IdentityManagementErrors.Unauthenticated();
        var user = await store.FindUserByIdAsync(userId, ct);
        if (user is null) return IdentityManagementErrors.UserNotFound();
        user.SetNotificationPrefs(request.Preferences.ToJson());
        await store.SaveChangesAsync(ct);
        return request.Preferences;
    }
}
