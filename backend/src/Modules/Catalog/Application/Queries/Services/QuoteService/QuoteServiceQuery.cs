using CareSitter.Contracts.Services;
using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Catalog.Application.Queries.QuoteService;

public sealed record QuoteServiceQuery(
    Guid ServiceTypeId,
    DateTimeOffset ScheduledStart,
    DateTimeOffset ScheduledEnd) : IRequest<Result<PriceQuote>>;
