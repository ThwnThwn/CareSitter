using System.Text.Json;

namespace CareSitter.Modules.People.Application;

public sealed record CaregiverKycResponse(
    Guid Id,
    Guid UserId,
    string? FullName,
    DateOnly? DateOfBirth,
    string? Gender,
    string KycStatus,
    string? CccdFrontUrl,
    string? CccdBackUrl,
    string[] CertificateUrls,
    DateTimeOffset CreatedAt,
    DateTimeOffset UpdatedAt,
    Guid? CccdFrontMediaId = null, Guid? CccdBackMediaId = null,
    Guid[]? CertificateMediaIds = null, bool RequiresSecureResubmission = false);
