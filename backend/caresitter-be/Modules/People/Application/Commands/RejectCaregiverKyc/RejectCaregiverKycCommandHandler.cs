using CareSitter.Infrastructure.Security;
using CareSitter.Modules.People.Domain;
using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.People.Application.Commands.RejectCaregiverKyc;

internal sealed class RejectCaregiverKycCommandHandler(
    IPeopleRepository repository,
    ICurrentUser currentUser)
    : IRequestHandler<RejectCaregiverKycCommand, Result<CaregiverKycRejectionResponse>>
{
    public async Task<Result<CaregiverKycRejectionResponse>> Handle(
        RejectCaregiverKycCommand request, CancellationToken ct)
    {
        if (!currentUser.IsInRole("ADMIN")) return PeopleErrors.Forbidden();

        var profile = await repository.GetCaregiverProfileByIdAsync(request.CaregiverId, ct);
        if (profile is null) return PeopleErrors.NotFound();

        var result = profile.RejectKyc();
        if (result.IsFailure) return result.Error;

        await repository.SaveChangesAsync(ct);
        return new CaregiverKycRejectionResponse(profile.Id, profile.KycStatus, request.Reason);
    }
}
