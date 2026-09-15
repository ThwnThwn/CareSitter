using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Catalog.Application.Commands.DeleteAddress;

public sealed record DeleteAddressCommand(Guid AddressId) : IRequest<Result<Unit>>;
