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
    IValidator<SubmitCaregiverKycCommand> validator)
    : IRequestHandler<SubmitCaregiverKycCommand, Result<CaregiverKycSubmissionResponse>>
{
    public async Task<Result<CaregiverKycSubmissionResponse>> Handle(
        SubmitCaregiverKycCommand request, CancellationToken ct)
    {
        if (currentUser.UserId is not { } userId) return PeopleErrors.Unauthenticated();

        var profile = await repository.GetCaregiverProfileByUserIdAsync(userId, true, ct);
        if (profile is null) return PeopleErrors.CaregiverProfileNotFound();

        var validation = await validator.ValidateAsync(request, ct);
        if (!validation.IsValid)
            return Error.Validation(validation.Errors[0].ErrorCode,
                validation.Errors[0].ErrorMessage);

        var cccdNumber = request.CccdNumber?.Trim() ?? string.Empty;
        var certificateUrls = (request.CertificateUrls ?? Array.Empty<string>())
            .Where(x => !string.IsNullOrWhiteSpace(x))
            .Select(x => x.Trim())
            .Distinct(StringComparer.OrdinalIgnoreCase)
            .ToArray();

        var cccdEncrypted = encryption.Encrypt(cccdNumber);
        var cccdHash = encryption.Hmac(cccdNumber);

        var result = profile.SubmitKyc(cccdEncrypted, cccdHash,
            request.CccdFrontUrl!.Trim(), request.CccdBackUrl!.Trim(),
            JsonSerializer.Serialize(certificateUrls));
        if (result.IsFailure) return result.Error;

        await repository.SaveChangesAsync(ct);
        return new CaregiverKycSubmissionResponse(profile.KycStatus,
            profile.CccdFrontUrl, profile.CccdBackUrl, certificateUrls,
            "Hồ sơ KYC đã được nộp.");
    }
}
