namespace CareSitter.Modules.Catalog.Controllers;

public sealed record QuoteRequest(DateTimeOffset ScheduledStart, DateTimeOffset ScheduledEnd);
