using CareSitter.Contracts.Services;
using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Catalog.Application.Commands.QuoteService;

public sealed record QuoteServiceCommand(
    Guid ServiceTypeId,
    DateTimeOffset ScheduledStart,
    DateTimeOffset ScheduledEnd) : IRequest<Result<PriceQuote>>;
