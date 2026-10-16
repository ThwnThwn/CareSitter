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
    CatalogClinicalReview? ClinicalReview);

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
    decimal? YieldFactor);

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
    string? Notes);

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
