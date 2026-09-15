using System.Text.Json;

namespace CareSitter.Modules.People.Application;

public sealed record BeneficiaryResponse(Guid Id, string FullName, DateOnly? DateOfBirth,
    string? Gender, string? RelationshipToCustomer, string? Phone, Guid? DefaultAddressId,
    string? MobilityNote, string? GeneralNote, JsonElement? HealthHistory,
    JsonElement? Allergies, JsonElement? ChronicConditions, string? CareInstructions,
    JsonElement? EmergencyContacts, JsonElement? Medications);

public sealed record FamilyContactResponse(Guid Id, string FullName, string PhoneNumber, string? Note);

public sealed record CaregiverProfileResponse(Guid Id, Guid UserId, string? FullName,
    string? Gender, string? DateOfBirth, string? Bio, int? YearsOfExperience,
    decimal RatingAvg, int RatingCount, string KycStatus, string? CccdFrontUrl,
    string? CccdBackUrl, string[] CertificateUrls, string AvailabilityStatus,
    string? Skills, string? ServiceCity, string? ServiceDistrict, string? AvatarUrl);

public sealed record CaregiverProfileUpdateResponse(Guid Id, string? FullName,
    string? Bio, int? YearsOfExperience, string KycStatus, string AvailabilityStatus,
    string? ServiceCity, string? ServiceDistrict, string? Gender,
    string? DateOfBirth, string? Skills);

public sealed record CaregiverKycSubmissionResponse(string KycStatus,
    string? CccdFrontUrl, string? CccdBackUrl, string[] CertificateUrls, string Message);

public sealed record CaregiverAvailabilityResponse(Guid Id, string AvailabilityStatus);

public sealed record CaregiverProfileCreationResponse(
    CaregiverProfileResponse Profile, bool Created);

public sealed record CaregiverKycApprovalResponse(Guid Id, string KycStatus);

public sealed record CaregiverKycRejectionResponse(Guid Id, string KycStatus, string? Reason);
