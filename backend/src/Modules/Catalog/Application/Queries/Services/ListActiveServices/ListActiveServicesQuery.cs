using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Catalog.Application;

public sealed record ListActiveServicesQuery : IRequest<IReadOnlyList<ServiceCatalogResponse>>;
