using CareSitter.Infrastructure.Security;
using CareSitter.Modules.People.Domain;
using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.People.Application.Commands.ApproveCaregiverKyc;

internal sealed class ApproveCaregiverKycCommandHandler(
    IPeopleRepository repository,
    ICurrentUser currentUser)
    : IRequestHandler<ApproveCaregiverKycCommand, Result<CaregiverKycApprovalResponse>>
{
    public async Task<Result<CaregiverKycApprovalResponse>> Handle(
        ApproveCaregiverKycCommand request, CancellationToken ct)
    {
        if (!currentUser.IsInRole("ADMIN")) return PeopleErrors.Forbidden();

        var profile = await repository.GetCaregiverProfileByIdAsync(request.CaregiverId, ct);
        if (profile is null) return PeopleErrors.NotFound();

        var result = profile.ApproveKyc();
        if (result.IsFailure) return result.Error;

        await repository.SaveChangesAsync(ct);
        return new CaregiverKycApprovalResponse(profile.Id, profile.KycStatus);
    }
}
