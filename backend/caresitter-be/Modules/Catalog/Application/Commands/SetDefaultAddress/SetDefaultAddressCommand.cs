using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Catalog.Application.Commands.SetDefaultAddress;

public sealed record SetDefaultAddressCommand(Guid AddressId)
    : IRequest<Result<DefaultAddressResponse>>;
