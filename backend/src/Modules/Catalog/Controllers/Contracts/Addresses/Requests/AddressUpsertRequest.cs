using CareSitter.Modules.Catalog.Application;
using CareSitter.Modules.Catalog.Application.Commands.CreateAddress;
using CareSitter.Modules.Catalog.Application.Commands.DeleteAddress;
using CareSitter.Modules.Catalog.Application.Commands.SetDefaultAddress;
using CareSitter.Modules.Catalog.Application.Commands.UpdateAddress;

namespace CareSitter.Modules.Catalog.Controllers;

public sealed record AddressUpsertRequest(
    string PlaceId,
    string? SessionToken,
    string? Label,
    string? Note = null);
