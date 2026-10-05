using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Catalog.Application;

public sealed record GetOwnedAddressQuery(Guid AddressId) : IRequest<Result<AddressResponse>>;
