namespace CareSitter.Messaging.Contracts.Events;

/// <summary>References a committed payment without exposing financial provider payloads.</summary>
public sealed record PaymentSucceeded(Guid BookingId, Guid PaymentIntentId, DateTimeOffset OccurredAt);
