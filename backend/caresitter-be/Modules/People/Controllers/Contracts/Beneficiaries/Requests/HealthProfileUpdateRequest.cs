using System.Text.Json;

namespace CareSitter.Modules.People.Controllers;

public sealed record HealthProfileUpdateRequest(long ExpectedHealthRevision, JsonElement Changes);
