using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Catalog.Application.Commands.UpdateAddress;

public sealed record UpdateAddressCommand(
    Guid AddressId,
    string? PlaceId,
    string? SessionToken,
    string? Label,
    string? Note) : IRequest<Result<AddressResponse>>;
