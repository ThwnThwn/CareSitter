using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Catalog.Application;

public sealed record GetActiveServiceQuery(Guid ServiceId) : IRequest<ServiceCatalogResponse?>;
