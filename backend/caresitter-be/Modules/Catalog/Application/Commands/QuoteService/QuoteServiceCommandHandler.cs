using CareSitter.Contracts.Services;
using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Catalog.Application.Commands.QuoteService;

internal sealed class QuoteServiceCommandHandler(IPricingService pricing)
    : IRequestHandler<QuoteServiceCommand, Result<PriceQuote>>
{
    public Task<Result<PriceQuote>> Handle(QuoteServiceCommand request, CancellationToken ct) =>
        pricing.QuoteAsync(request.ServiceTypeId, request.ScheduledStart, request.ScheduledEnd, ct);
}
