using System.Text.Json;

namespace CareSitter.Modules.People.Application;

public sealed record CaregiverProfileResponse(Guid Id, Guid UserId, string? FullName,
    string? Gender, string? DateOfBirth, string? Bio, int? YearsOfExperience,
    decimal RatingAvg, int RatingCount, string KycStatus, string? CccdFrontUrl,
    string? CccdBackUrl, string[] CertificateUrls, string AvailabilityStatus,
    string? Skills, string? ServiceCity, string? ServiceDistrict, string? AvatarUrl,
    Guid? CccdFrontMediaId = null, Guid? CccdBackMediaId = null,
    Guid[]? CertificateMediaIds = null, bool RequiresSecureResubmission = false);
