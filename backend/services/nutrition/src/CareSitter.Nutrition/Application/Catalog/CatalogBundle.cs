using CareSitter.Nutrition.Domain;

namespace CareSitter.Nutrition.Application.Catalog;

public sealed record CatalogBundle(
    int SchemaVersion,
    string PackageKey,
    CatalogSupportedScope[] SupportedScopes,
    CatalogCitation[] Citations,
    NutritionConcept[] Concepts,
    CatalogRecipeVersion[] Recipes,
    CatalogRuleVersion[] Rules);

public sealed record CatalogSupportedScope(
    string Code,
    string Population,
    string[] ConditionCodes,
    string MedicationPolicy,
    string[] BlockedSpecialNeeds);

public sealed record CatalogCitation(
    string Id,
    string Title,
    string Organization,
    int Year,
    string? Edition,
    string? Chapter,
    string? PrintedPages,
    string? PdfPages,
    string Locator,
    string Reference,
    DateOnly VerifiedOn,
    string? FileSha256);

public sealed record CatalogRecipeVersion(Guid RecipeId, int Version, Recipe Payload);

public sealed record CatalogRuleVersion(Guid RuleId, int Version, DietaryRule Payload);

public sealed record CatalogValidationIssue(string Path, string Code, string Message);

public sealed record CatalogValidationResult(IReadOnlyList<CatalogValidationIssue> Issues)
{
    public bool IsValid => Issues.Count == 0;
}
