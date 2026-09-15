using CareSitter.SharedKernel.Results;

namespace CareSitter.Modules.People.Application.Commands;

internal static class PeopleErrors
{
    public const string UnauthenticatedCode = "people.unauthenticated";
    public const string NotFoundCode = "people.not_found";
    public const string CaregiverProfileNotFoundCode = "people.caregiver_profile.not_found";
    public const string ForbiddenCode = "people.forbidden";
    public const string InvalidCccdCode = "people.kyc.invalid_cccd";
    public const string InvalidCccdImageUrlsCode = "people.kyc.invalid_cccd_image_urls";
    public const string InvalidCertificateUrlsCode = "people.kyc.invalid_certificate_urls";

    public static Error Unauthenticated() =>
        Error.Unauthorized(UnauthenticatedCode, string.Empty);
    public static Error NotFound() => Error.NotFound(NotFoundCode, string.Empty);
    public static Error CaregiverProfileNotFound() => Error.NotFound(
        CaregiverProfileNotFoundCode, "Caregiver profile khong ton tai.");
    public static Error Forbidden() => Error.Forbidden(ForbiddenCode, string.Empty);
    public static Error FamilyPhoneExists() => Error.Conflict(
        "family_contact.phone_exists", "So dien thoai nay da co trong danh ba gia dinh.");
}
