using CareSitter.Contracts.Services;
using CareSitter.Modules.People.Application.Commands;
using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.People.Application;

internal sealed class GetMyCaregiverProfileQueryHandler(
    IPeopleReadStore store,
    IUserProfileReader userProfiles,
    ICurrentUser currentUser) : IRequestHandler<GetMyCaregiverProfileQuery, Result<CaregiverProfileResponse>>
{
    public async Task<Result<CaregiverProfileResponse>> Handle(
        GetMyCaregiverProfileQuery request, CancellationToken ct)
    {
        if (currentUser.UserId is not { } userId) return PeopleErrors.Unauthenticated();
        var avatarUrl = await userProfiles.GetAvatarUrlAsync(userId, ct);
        var profile = await store.GetCaregiverProfileAsync(userId, avatarUrl, ct);
        return profile is null ? PeopleErrors.CaregiverProfileNotFound() : profile;
    }
}
