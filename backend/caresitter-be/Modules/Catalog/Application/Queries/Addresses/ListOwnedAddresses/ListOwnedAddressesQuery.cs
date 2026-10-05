using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Catalog.Application;

public sealed record ListOwnedAddressesQuery : IRequest<Result<IReadOnlyList<AddressResponse>>>;
