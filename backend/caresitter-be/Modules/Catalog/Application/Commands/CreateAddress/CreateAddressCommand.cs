using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Catalog.Application.Commands.CreateAddress;

public sealed record CreateAddressCommand(
    string? PlaceId,
    string? SessionToken,
    string? Label,
    string? Note) : IRequest<Result<AddressResponse>>;
