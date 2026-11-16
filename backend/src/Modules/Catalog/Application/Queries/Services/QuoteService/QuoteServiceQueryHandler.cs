using CareSitter.Contracts.Services;
using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Catalog.Application.Queries.QuoteService;

internal sealed class QuoteServiceQueryHandler(IPricingService pricing)
    : IRequestHandler<QuoteServiceQuery, Result<PriceQuote>>
{
    public Task<Result<PriceQuote>> Handle(QuoteServiceQuery request, CancellationToken ct) =>
        pricing.QuoteAsync(request.ServiceTypeId, request.ScheduledStart, request.ScheduledEnd, ct);
}
