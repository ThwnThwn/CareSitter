using System.Text.Json;
using CareSitter.Contracts.Services;
using CareSitter.Modules.People.Domain;
using CareSitter.SharedKernel.Results;
using FluentValidation;
using MediatR;

namespace CareSitter.Modules.People.Application.Commands.SubmitCaregiverKyc;

internal sealed class SubmitCaregiverKycCommandHandler(
    IPeopleRepository repository,
    ICurrentUser currentUser,
    IEncryptionService encryption,
    IKycMediaStore media,
    IValidator<SubmitCaregiverKycCommand> validator)
    : IRequestHandler<SubmitCaregiverKycCommand, Result<CaregiverKycSubmissionResponse>>
{
    public async Task<Result<CaregiverKycSubmissionResponse>> Handle(
        SubmitCaregiverKycCommand request, CancellationToken ct)
    {
        if (currentUser.UserId is not { } userId) return PeopleErrors.Unauthenticated();
        if (!currentUser.IsInRole("CAREGIVER")) return PeopleErrors.Forbidden();

        var profile = await repository.GetCaregiverProfileByUserIdAsync(userId, true, ct);
        if (profile is null) return PeopleErrors.CaregiverProfileNotFound();

        var validation = await validator.ValidateAsync(request, ct);
        if (!validation.IsValid)
            return Error.Validation(validation.Errors[0].ErrorCode,
                validation.Errors[0].ErrorMessage);

        var cccdNumber = request.CccdNumber?.Trim() ?? string.Empty;
        var certificates = request.CertificateMediaIds ?? [];
        var mediaValidation = await KycMediaPolicy.ValidateSubmissionAsync(media, userId,
            request.CccdFrontMediaId, request.CccdBackMediaId, certificates, ct);
        if (mediaValidation.IsFailure) return mediaValidation.Error;

        var cccdEncrypted = encryption.Encrypt(cccdNumber);
        var cccdHash = encryption.Hmac(cccdNumber);

        var result = profile.SubmitSecureKyc(cccdEncrypted, cccdHash,
            request.CccdFrontMediaId, request.CccdBackMediaId,
            JsonSerializer.Serialize(certificates));
        if (result.IsFailure) return result.Error;

        await repository.SaveChangesAsync(ct);
        return new CaregiverKycSubmissionResponse(profile.KycStatus,
            null, null, [], "Hồ sơ KYC đã được nộp.",
            profile.CccdFrontMediaId, profile.CccdBackMediaId, certificates);
    }
}
