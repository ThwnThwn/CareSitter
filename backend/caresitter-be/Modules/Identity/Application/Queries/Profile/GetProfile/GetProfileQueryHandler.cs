using CareSitter.Contracts.Services;
using CareSitter.Modules.Identity.Application.UpdateProfile;
using CareSitter.Modules.Identity.Domain;
using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Identity.Application;

internal sealed class GetProfileQueryHandler(IIdentityStore store, ICurrentUser currentUser)
    : IRequestHandler<GetProfileQuery, Result<ProfileResponse>>
{
    public async Task<Result<ProfileResponse>> Handle(GetProfileQuery request, CancellationToken ct)
    {
        if (currentUser.UserId is not { } userId) return IdentityManagementErrors.Unauthenticated();
        var user = await store.FindUserByIdAsync(userId, ct);
        return user is null ? IdentityManagementErrors.UserNotFound() : ToProfile(user);
    }

    internal static ProfileResponse ToProfile(User user) => new(
        user.Id, user.Phone, user.Email, user.FullName!, user.DisplayName!, user.DateOfBirth,
        user.Gender, user.AvatarMediaId, user.AvatarUrl, user.DefaultAddressId, user.Roles);
}
