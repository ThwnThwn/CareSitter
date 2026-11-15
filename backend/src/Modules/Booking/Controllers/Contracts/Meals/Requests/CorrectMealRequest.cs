namespace CareSitter.Modules.Booking.Controllers;

public sealed record CorrectMealRequest(string Outcome, string? Note, string Reason, int ExpectedRevision);
