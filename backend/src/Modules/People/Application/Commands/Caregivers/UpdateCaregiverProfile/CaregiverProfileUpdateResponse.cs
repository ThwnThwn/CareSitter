using System.Text.Json;

namespace CareSitter.Modules.People.Application;

public sealed record CaregiverProfileUpdateResponse(Guid Id, string? FullName,
    string? Bio, int? YearsOfExperience, string KycStatus, string AvailabilityStatus,
    string? ServiceCity, string? ServiceDistrict, string? Gender,
    string? DateOfBirth, string? Skills);
