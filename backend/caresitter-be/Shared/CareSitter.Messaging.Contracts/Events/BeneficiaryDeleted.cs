namespace CareSitter.Messaging.Contracts.Events;

/// <summary>Only opaque IDs cross the broker; Nutrition owns removal of its health data.</summary>
public sealed record BeneficiaryDeleted(Guid OwnerUserId, Guid BeneficiaryId, DateTimeOffset OccurredAt);
