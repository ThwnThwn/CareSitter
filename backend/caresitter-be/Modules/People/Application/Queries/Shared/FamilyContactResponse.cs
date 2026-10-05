using System.Text.Json;

namespace CareSitter.Modules.People.Application;

public sealed record FamilyContactResponse(Guid Id, string FullName, string PhoneNumber, string? Note);
