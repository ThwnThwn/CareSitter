using System.Text.Json;

namespace CareSitter.Modules.People.Application;

public sealed record CaregiverProfileCreationResponse(
    CaregiverProfileResponse Profile, bool Created);
