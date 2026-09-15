using CareSitter.Infrastructure.Security;
using CareSitter.Modules.People.Domain;
using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.People.Application.Commands.CreateCaregiverProfile;

internal sealed class CreateCaregiverProfileCommandHandler(
    IPeopleRepository repository,
    ICurrentUser currentUser)
    : IRequestHandler<CreateCaregiverProfileCommand, Result<CaregiverProfileCreationResponse>>
{
    public async Task<Result<CaregiverProfileCreationResponse>> Handle(
        CreateCaregiverProfileCommand request, CancellationToken ct)
    {
        if (currentUser.UserId is not { } userId) return PeopleErrors.Unauthenticated();
        if (!currentUser.IsInRole("CAREGIVER")) return PeopleErrors.Forbidden();

        var existing = await repository.GetCaregiverProfileByUserIdAsync(userId, true, ct);
        if (existing is not null)
            return new CaregiverProfileCreationResponse(
                PeopleResponseMapper.ToProfileResponse(existing), false);

        var created = CaregiverProfile.Create(userId);
        if (created.IsFailure) return created.Error;
        var updated = created.Value.UpdateProfile(fullName: request.FullName?.Trim());
        if (updated.IsFailure) return updated.Error;

        var saved = await repository.AddCaregiverProfileIdempotentlyAsync(
            created.Value, userId, ct);
        return new CaregiverProfileCreationResponse(
            PeopleResponseMapper.ToProfileResponse(saved.Profile), saved.Created);
    }
}
