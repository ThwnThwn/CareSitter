using CareSitter.Contracts.Services;
using CareSitter.Modules.People.Domain;
using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.People.Application.Commands.UpdateCaregiverProfile;

internal sealed class UpdateCaregiverProfileCommandHandler(
    IPeopleRepository repository,
    ICurrentUser currentUser)
    : IRequestHandler<UpdateCaregiverProfileCommand, Result<CaregiverProfileUpdateResponse>>
{
    public async Task<Result<CaregiverProfileUpdateResponse>> Handle(
        UpdateCaregiverProfileCommand request, CancellationToken ct)
    {
        if (currentUser.UserId is not { } userId) return PeopleErrors.Unauthenticated();

        var profile = await repository.GetCaregiverProfileByUserIdAsync(userId, true, ct);
        if (profile is null) return PeopleErrors.CaregiverProfileNotFound();

        var result = profile.UpdateProfile(request.FullName, request.Bio,
            request.YearsOfExperience, request.Skills, request.ServiceCity,
            request.ServiceDistrict, request.Gender, request.DateOfBirth);
        if (result.IsFailure) return result.Error;

        await repository.SaveChangesAsync(ct);
        return new CaregiverProfileUpdateResponse(profile.Id, profile.FullName,
            profile.Bio, profile.YearsOfExperience, profile.KycStatus,
            profile.AvailabilityStatus, profile.ServiceCity, profile.ServiceDistrict,
            profile.Gender, profile.DateOfBirth?.ToString("yyyy-MM-dd"), profile.Skills);
    }
}
