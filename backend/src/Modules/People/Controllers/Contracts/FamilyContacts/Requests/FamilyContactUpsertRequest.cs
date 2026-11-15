using CareSitter.Modules.People.Application;
using CareSitter.Modules.People.Application.Commands.CreateFamilyContact;
using CareSitter.Modules.People.Application.Commands.DeleteFamilyContact;
using CareSitter.Modules.People.Application.Commands.UpdateFamilyContact;

namespace CareSitter.Modules.People.Controllers;

public sealed record FamilyContactUpsertRequest(string FullName, string PhoneNumber, string? Note);
