using System.Text.Json;

namespace CareSitter.Modules.People.Application;

public sealed record CaregiverKycSubmissionResponse(string KycStatus,
    string? CccdFrontUrl, string? CccdBackUrl, string[] CertificateUrls, string Message,
    Guid? CccdFrontMediaId = null, Guid? CccdBackMediaId = null, Guid[]? CertificateMediaIds = null);
