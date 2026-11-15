using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Identity.Application;

public sealed record SetDefaultAddressCommand(Guid AddressId) : IRequest<Result<Guid>>;
