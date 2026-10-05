using System.Text.Json;

namespace CareSitter.Modules.People.Application;

public sealed record CaregiverAvailabilityResponse(Guid Id, string AvailabilityStatus);
