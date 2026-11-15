using CareSitter.Modules.Catalog.Application;
using CareSitter.Modules.Catalog.Application.Commands.QuoteService;

namespace CareSitter.Modules.Catalog.Controllers;

public sealed record QuoteRequest(DateTimeOffset ScheduledStart, DateTimeOffset ScheduledEnd);
