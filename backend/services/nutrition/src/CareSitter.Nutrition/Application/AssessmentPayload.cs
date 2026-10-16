using CareSitter.Nutrition.Contracts;
using CareSitter.Nutrition.Domain;

namespace CareSitter.Nutrition.Application;

public sealed record AssessmentPayload(int SchemaVersion, BeneficiaryHealthSnapshot Input,
    HealthFact[] Facts, NutritionDecision Decision, string? ErrorCode = null, bool Retryable = false,
    DateTimeOffset? ConfirmedAt = null, string PolicyVersion = "1", long CatalogRevision = 0,
    HealthUnresolvedStatement[]? ParserUnresolved = null, string[]? IrrelevantSourceKeys = null,
    int? ParserSchemaVersion = null, long? ParserDictionaryRevision = null, string? ParserPromptVersion = null,
    int? ParserGraphSchemaVersion = null, long? ParserGraphRevision = null, string? ParserRetrievalStrategy = null);
