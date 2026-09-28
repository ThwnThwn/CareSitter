using CareSitter.SharedKernel.Results;

namespace CareSitter.Modules.Catalog.Application.Commands;

internal static class CatalogErrors
{
    public const string UnauthenticatedCode = "catalog.unauthenticated";
    public const string AddressNotFoundCode = "catalog.address.not_found";
    public const string PlaceServiceUnavailableCode = "catalog.place_service.unavailable";
    public const string PlaceNotFoundCode = "catalog.place.not_found";
    public const string VerifiedPlaceRequiredCode = "catalog.address.verified_place_required";
    public const string InvalidCoordinatesCode = "catalog.address.invalid_coordinates";
    public const string AddressInUseCode = "catalog.address.in_use";

    public static Error Unauthenticated() =>
        Error.Unauthorized(UnauthenticatedCode, string.Empty);

    public static Error AddressNotFound() =>
        Error.NotFound(AddressNotFoundCode, string.Empty);

    public static Error PlaceServiceUnavailable(string message) =>
        Error.Unavailable(PlaceServiceUnavailableCode, message);

    public static Error PlaceNotFound() =>
        Error.NotFound(PlaceNotFoundCode,
            "Dia chi khong hop le hoac khong thuoc Viet Nam.");

    public static Error VerifiedPlaceRequired() =>
        Error.Validation(VerifiedPlaceRequiredCode,
            "Vui long chon dia chi tu danh sach goi y.");

    public static Error InvalidCoordinates() =>
        Error.Validation(InvalidCoordinatesCode, "Toa do khong hop le.");

    public static Error AddressInUse() =>
        Error.Conflict(AddressInUseCode,
            "Dia chi dang duoc su dung va không thể xoa.");
}
