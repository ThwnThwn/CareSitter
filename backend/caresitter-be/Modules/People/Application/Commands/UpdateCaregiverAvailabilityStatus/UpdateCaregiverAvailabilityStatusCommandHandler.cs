using CareSitter.Contracts.Services;
using CareSitter.Modules.People.Domain;
using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.People.Application.Commands.UpdateCaregiverAvailabilityStatus;

internal sealed class UpdateCaregiverAvailabilityStatusCommandHandler(
    IPeopleRepository repository,
    ICurrentUser currentUser)
    : IRequestHandler<UpdateCaregiverAvailabilityStatusCommand, Result<CaregiverAvailabilityResponse>>
{
    public async Task<Result<CaregiverAvailabilityResponse>> Handle(
        UpdateCaregiverAvailabilityStatusCommand request, CancellationToken ct)
    {
        if (currentUser.UserId is not { } userId) return PeopleErrors.Unauthenticated();

        var profile = await repository.GetCaregiverProfileByUserIdAsync(userId, true, ct);
        if (profile is null) return PeopleErrors.CaregiverProfileNotFound();

        var result = profile.SetAvailabilityStatus(request.Status);
        if (result.IsFailure) return result.Error;

        await repository.SaveChangesAsync(ct);
        return new CaregiverAvailabilityResponse(profile.Id, profile.AvailabilityStatus);
    }
}
