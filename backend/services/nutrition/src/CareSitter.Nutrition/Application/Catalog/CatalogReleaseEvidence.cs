namespace CareSitter.Nutrition.Application.Catalog;

public sealed record CatalogReleaseEvidence(
    int SchemaVersion,
    string PackageKey,
    string BundleFileSha256,
    string ContentStatus,
    string CalculationBasis,
    string[] RequiredNutrients,
    CatalogRecipeEvidence[] Recipes,
    CatalogRuleEvidence[] Rules,
    CatalogClinicalReview? ClinicalReview,
    string? ReleaseProfile = null,
    CatalogKnowledgeReview? KnowledgeReview = null,
    CatalogSourcePublicationReview? SourcePublication = null,
    CatalogReleaseAuthorization? ReleaseAuthorization = null);

public sealed record CatalogRecipeEvidence(
    Guid RecipeVersionId,
    CatalogIngredientEvidence[] Ingredients,
    CatalogNutrientEvidence[] Nutrients,
    string[] UnresolvedItems);

public sealed record CatalogIngredientEvidence(
    string IngredientCode,
    string SourceId,
    string SourceLocator,
    string AmountBasis,
    Dictionary<string, decimal> NutrientsPer100G,
    decimal? EdiblePortionFactor,
    decimal? YieldFactor,
    string? SourceReferenceCode = null);

public sealed record CatalogNutrientEvidence(
    string Key,
    decimal? Value,
    string Unit,
    string Method,
    string[] SourceIds,
    string Calculation);

public sealed record CatalogRuleEvidence(
    Guid RuleVersionId,
    string[] SourceIds,
    string SourceLocator,
    string[] UnresolvedItems);

public sealed record CatalogClinicalReview(
    string ReviewerName,
    string Credentials,
    DateTimeOffset ReviewedAt,
    string Decision,
    string? Notes,
    string? ReviewerId = null);

public sealed record CatalogKnowledgeReview(
    int SchemaVersion,
    string CandidateGraphSha256,
    string DecisionLedgerSha256,
    string ReviewedGraphSha256,
    int CandidateCount,
    int ApprovedCount,
    int PendingCount,
    int RejectedCount,
    CatalogKnowledgeSourceReview[] Sources,
    string[] ClinicalReviewerIds,
    string Decision,
    string[]? ReleaseAuthorityIds = null);

public sealed record CatalogSourcePublicationReview(
    string SourceId,
    string SourceRevisionId,
    string DocumentSha256,
    string Organization,
    int PublicationYear,
    DateTimeOffset VerifiedAt,
    string Decision);

public sealed record CatalogReleaseAuthorization(
    string AuthorizationId,
    string AuthorityType,
    string AuthorizedBy,
    DateTimeOffset AuthorizedAt,
    string Decision,
    string? Notes);

public sealed record CatalogKnowledgeSourceReview(
    string SourceRevisionId,
    string RightsStatus);

public sealed record CatalogCombinationCoverage(
    string ScopeCode,
    string? ConditionCode,
    int BreakfastOptions,
    int LunchOptions,
    int DinnerOptions,
    int ValidCombinations);

public sealed record CatalogReleaseValidationResult(
    IReadOnlyList<CatalogValidationIssue> Issues,
    IReadOnlyList<CatalogCombinationCoverage> Combinations)
{
    public bool IsReleaseReady => Issues.Count == 0;
}
