using System.Text.Json;

namespace CareSitter.Modules.People.Application;

public sealed record CaregiverResponse(
    Guid Id,
    Guid UserId,
    string? FullName,
    string? Bio,
    int? YearsOfExperience,
    decimal RatingAvg,
    int RatingCount,
    string AvailabilityStatus,
    JsonElement? Skills,
    string? ServiceCity,
    string? ServiceDistrict,
    double? ServiceCenterLat,
    double? ServiceCenterLng,
    int? ServiceRadiusMeters,
    int? DistanceMeters);
