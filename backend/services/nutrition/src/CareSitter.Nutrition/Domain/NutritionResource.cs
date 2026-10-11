namespace CareSitter.Nutrition.Domain;

public sealed record NutritionResource(Guid Id, Guid CustomerId, Guid BeneficiaryId,
    long HealthRevision, string Status, string Payload, Guid IdempotencyKey, string Fingerprint,
    DateTimeOffset CreatedAt);
