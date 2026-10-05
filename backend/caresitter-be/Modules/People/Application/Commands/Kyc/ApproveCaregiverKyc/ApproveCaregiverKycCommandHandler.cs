using CareSitter.Contracts.Services;
using CareSitter.Modules.People.Domain;
using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.People.Application.Commands.ApproveCaregiverKyc;

internal sealed class ApproveCaregiverKycCommandHandler(
    IPeopleRepository repository,
    ICurrentUser currentUser,
    IKycMediaStore media,
    IAuditLogger auditLogger)
    : IRequestHandler<ApproveCaregiverKycCommand, Result<CaregiverKycApprovalResponse>>
{
    public async Task<Result<CaregiverKycApprovalResponse>> Handle(
        ApproveCaregiverKycCommand request, CancellationToken ct)
    {
        if (!currentUser.IsInRole("ADMIN")) return PeopleErrors.Forbidden();

        var profile = await repository.GetCaregiverProfileByIdAsync(request.CaregiverId, ct);
        if (profile is null) return PeopleErrors.NotFound();

        var mediaValidation = await KycMediaPolicy.ValidateSubmissionAsync(media, profile.UserId,
            profile.CccdFrontMediaId, profile.CccdBackMediaId,
            PeopleResponseMapper.CertificateIds(profile), ct);
        if (mediaValidation.IsFailure) return mediaValidation.Error;

        var before = new { profile.KycStatus };
        var result = profile.ApproveKyc();
        if (result.IsFailure) return result.Error;

        await repository.SaveChangesAsync(ct);
        await auditLogger.WriteAsync("ADMIN_KYC_APPROVED", "CaregiverProfile", profile.Id,
            before, new { profile.KycStatus, profile.UserId }, ct);
        return new CaregiverKycApprovalResponse(profile.Id, profile.KycStatus);
    }
}
