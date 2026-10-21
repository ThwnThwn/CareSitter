using System.Text.RegularExpressions;
using CareSitter.Nutrition.Domain;

namespace CareSitter.Nutrition.Application.Catalog;

public static class CatalogReleaseValidator
{
    public const int EvidenceSchemaVersion = 1;
    public static readonly IReadOnlySet<string> RequiredP2Nutrients = new HashSet<string>(StringComparer.Ordinal)
    {
        "energy_kcal", "protein_g", "carbohydrate_g", "fat_g", "fiber_g", "sodium_mg"
    };

    public static CatalogReleaseValidationResult Validate(
        CatalogBundle? bundle,
        CatalogReleaseEvidence? evidence,
        string actualBundleFileSha256)
    {
        var issues = new List<CatalogValidationIssue>();
        var combinations = new List<CatalogCombinationCoverage>();
        void Add(string path, string code, string message) => issues.Add(new(path, code, message));

        var baseResult = CatalogBundleValidator.Validate(bundle);
        issues.AddRange(baseResult.Issues);
        if (bundle is null || evidence is null)
        {
            if (evidence is null) Add("evidence", "required", "Release evidence is required.");
            return new(issues, combinations);
        }

        if (evidence.SchemaVersion != EvidenceSchemaVersion)
            Add("evidence.schemaVersion", "unsupported", $"Only evidence schema version {EvidenceSchemaVersion} is supported.");
        if (!string.Equals(evidence.PackageKey, bundle.PackageKey, StringComparison.Ordinal))
            Add("evidence.packageKey", "bundle_mismatch", "Evidence package key must match the catalog bundle.");
        if (!IsSha256(evidence.BundleFileSha256) ||
            !string.Equals(evidence.BundleFileSha256, actualBundleFileSha256, StringComparison.OrdinalIgnoreCase))
            Add("evidence.bundleFileSha256", "bundle_mismatch", "Evidence must be bound to the exact catalog bundle file.");
        if (evidence.ContentStatus != "review_ready")
            Add("evidence.contentStatus", "not_review_ready", "Content status must be review_ready before release.");
        var releaseProfile = evidence.ReleaseProfile ?? "adult_condition_v1";
        if (releaseProfile is not ("adult_baseline_v1" or "adult_condition_v1"))
            Add("evidence.releaseProfile", "unsupported", "Release profile must be adult_baseline_v1 or adult_condition_v1.");
        if (releaseProfile == "adult_baseline_v1")
        {
            if ((bundle.Rules ?? []).Length > 0)
                Add("rules", "baseline_rule_forbidden", "Baseline release cannot contain disease rules.");
            if ((bundle.SupportedScopes ?? []).Any(scope => (scope?.ConditionCodes ?? []).Length > 0))
                Add("supportedScopes", "baseline_condition_scope_forbidden", "Baseline release cannot enable disease conditions.");
        }
        if (string.IsNullOrWhiteSpace(evidence.CalculationBasis))
            Add("evidence.calculationBasis", "required", "Calculation basis is required.");

        var required = (evidence.RequiredNutrients ?? []).ToHashSet(StringComparer.Ordinal);
        foreach (var nutrient in RequiredP2Nutrients)
            if (!required.Contains(nutrient))
                Add("evidence.requiredNutrients", "nutrient_missing", $"P2 requires nutrient {nutrient}.");
        foreach (var nutrient in required)
            if (!CatalogPolicyVocabulary.NutrientUnits.ContainsKey(nutrient))
                Add("evidence.requiredNutrients", "unsupported_nutrient", $"Nutrient {nutrient} has no approved unit mapping.");
        foreach (var nutrient in (bundle.Rules ?? [])
                     .SelectMany(rule => (rule.Payload?.DailyMaximums?.Keys.AsEnumerable() ?? Enumerable.Empty<string>()).Concat(
                         (rule.Payload?.NutrientConstraints ?? []).Select(constraint => constraint.NutrientKey)))
                     .Where(key => !string.IsNullOrWhiteSpace(key))
                     .Distinct(StringComparer.Ordinal))
            if (!required.Contains(nutrient))
                Add("evidence.requiredNutrients", "rule_nutrient_missing", $"Release evidence must recompute nutrient {nutrient} used by a disease rule.");

        var recipes = bundle.Recipes ?? [];
        foreach (var mealType in CatalogPolicyVocabulary.MealTypes)
        {
            var count = recipes.Count(x => x.Payload?.MealType == mealType);
            if (count != 4) Add("recipes", "p2_meal_count", $"P2 requires exactly four {mealType} recipes; found {count}.");
        }
        if (recipes.Length != 12) Add("recipes", "p2_recipe_count", $"P2 requires exactly 12 recipes; found {recipes.Length}.");

        var recipeEvidence = (evidence.Recipes ?? [])
            .Where(x => x is not null)
            .GroupBy(x => x.RecipeVersionId)
            .ToDictionary(x => x.Key, x => x.ToArray());
        foreach (var group in recipeEvidence.Where(x => x.Value.Length > 1))
            Add("evidence.recipes", "duplicate", $"Recipe version {group.Key} has duplicate evidence.");

        for (var index = 0; index < recipes.Length; index++)
            ValidateRecipe(recipes[index], index, recipeEvidence, bundle.Citations ?? [], required, Add);

        var ruleEvidence = (evidence.Rules ?? [])
            .Where(x => x is not null)
            .GroupBy(x => x.RuleVersionId)
            .ToDictionary(x => x.Key, x => x.ToArray());
        foreach (var group in ruleEvidence.Where(x => x.Value.Length > 1))
            Add("evidence.rules", "duplicate", $"Rule version {group.Key} has duplicate evidence.");
        var rules = bundle.Rules ?? [];
        if (releaseProfile == "adult_condition_v1" && rules.Length == 0)
            Add("rules", "p2_rule_missing", "A condition release requires at least one disease rule.");
        for (var index = 0; index < rules.Length; index++)
            ValidateRule(rules[index], index, ruleEvidence, bundle.Citations ?? [], Add);

        var review = evidence.ClinicalReview;
        if (review is null) Add("evidence.clinicalReview", "clinical_review_required", "Clinical review is required before release.");
        else
        {
            if (string.IsNullOrWhiteSpace(review.ReviewerName)) Add("evidence.clinicalReview.reviewerName", "required", "Reviewer name is required.");
            if (string.IsNullOrWhiteSpace(review.ReviewerId)) Add("evidence.clinicalReview.reviewerId", "required", "Reviewer ID is required.");
            if (string.IsNullOrWhiteSpace(review.Credentials)) Add("evidence.clinicalReview.credentials", "required", "Reviewer credentials are required.");
            if (review.ReviewedAt == default) Add("evidence.clinicalReview.reviewedAt", "required", "Review time is required.");
            if (review.Decision != "approved") Add("evidence.clinicalReview.decision", "not_approved", "Clinical review decision must be approved.");
        }
        ValidateKnowledgeReview(evidence.KnowledgeReview, review, Add);

        combinations.Add(CountCombinations("baseline", null, recipes, [], []));
        foreach (var rule in rules)
        {
            if (rule?.Payload is null) continue;
            combinations.Add(CountCombinations(
                "condition-" + rule.Payload.ConditionCode.ToLowerInvariant(),
                rule.Payload.ConditionCode,
                recipes,
                [new("condition", rule.Payload.ConditionCode, rule.Payload.ConditionCode, "present", "current", "catalog_release", "release coverage", "beneficiary")],
                [rule.Payload]));
        }
        var allergyConcepts = (bundle.Concepts ?? []).Where(x => x.Kind == "food_allergy").ToArray();
        foreach (var allergy in allergyConcepts)
        {
            var allergyFact = new HealthFact("food_allergy", allergy.Code, allergy.Code, "present", "current", "catalog_release", "release coverage", "beneficiary");
            combinations.Add(CountCombinations(
                "allergy-" + allergy.Code.ToLowerInvariant(),
                null,
                recipes,
                [allergyFact],
                []));
            foreach (var rule in rules)
            {
                if (rule?.Payload is null) continue;
                combinations.Add(CountCombinations(
                    "condition-" + rule.Payload.ConditionCode.ToLowerInvariant() + "-allergy-" + allergy.Code.ToLowerInvariant(),
                    rule.Payload.ConditionCode,
                    recipes,
                    [new("condition", rule.Payload.ConditionCode, rule.Payload.ConditionCode, "present", "current", "catalog_release", "release coverage", "beneficiary"), allergyFact],
                    [rule.Payload]));
            }
        }
        foreach (var coverage in combinations)
        {
            if (coverage.BreakfastOptions < 2 || coverage.LunchOptions < 2 || coverage.DinnerOptions < 2)
                Add("coverage." + coverage.ScopeCode, "insufficient_options", "Each meal type needs at least two selectable options.");
            if (coverage.ValidCombinations == 0)
                Add("coverage." + coverage.ScopeCode, "no_valid_combination", "No complete breakfast/lunch/dinner combination satisfies the scope.");
        }

        return new(issues, combinations);
    }

    private static void ValidateRecipe(
        CatalogRecipeVersion version,
        int index,
        IReadOnlyDictionary<Guid, CatalogRecipeEvidence[]> evidenceById,
        CatalogCitation[] citations,
        IReadOnlySet<string> requiredNutrients,
        Action<string, string, string> add)
    {
        var path = $"evidence.recipes[{index}]";
        var recipe = version.Payload;
        if (recipe is null || !evidenceById.TryGetValue(recipe.VersionId, out var entries) || entries.Length == 0)
        {
            add(path, "evidence_missing", "Recipe release evidence is required.");
            return;
        }
        var evidence = entries[0];
        if ((evidence.UnresolvedItems ?? []).Any(x => !string.IsNullOrWhiteSpace(x)))
            add(path + ".unresolvedItems", "unresolved", "Recipe has unresolved source or calculation items.");

        var ingredientEvidence = (evidence.Ingredients ?? []).GroupBy(x => x.IngredientCode, StringComparer.Ordinal)
            .ToDictionary(x => x.Key, x => x.First(), StringComparer.Ordinal);
        foreach (var ingredient in recipe.Ingredients ?? [])
        {
            if (!ingredientEvidence.TryGetValue(ingredient.Code, out var item))
            {
                add(path + ".ingredients", "evidence_missing", $"Ingredient {ingredient.Code} has no source evidence.");
                continue;
            }
            if (!HasCitation(item.SourceId, citations)) add(path + ".ingredients", "unknown_reference", $"Citation {item.SourceId} does not exist in the bundle.");
            if (string.IsNullOrWhiteSpace(item.SourceLocator)) add(path + ".ingredients", "required", "Ingredient source locator is required.");
            if (!string.Equals(item.AmountBasis, ingredient.Basis, StringComparison.Ordinal)) add(path + ".ingredients", "basis_mismatch", $"Ingredient {ingredient.Code} amount basis does not match the recipe.");
            if (item.EdiblePortionFactor is null or <= 0 || item.YieldFactor is null or <= 0)
                add(path + ".ingredients", "factor_missing", $"Ingredient {ingredient.Code} needs positive edible-portion and yield factors.");
        }

        var nutrientEvidence = (evidence.Nutrients ?? []).GroupBy(x => x.Key, StringComparer.Ordinal)
            .ToDictionary(x => x.Key, x => x.First(), StringComparer.Ordinal);
        foreach (var key in requiredNutrients)
        {
            if (!recipe.Nutrients.TryGetValue(key, out var value) || value is null)
            {
                add(path + ".nutrients", "nutrient_missing", $"Recipe is missing {key}.");
                continue;
            }
            if (!nutrientEvidence.TryGetValue(key, out var nutrient))
            {
                add(path + ".nutrients", "evidence_missing", $"Nutrient {key} has no calculation evidence.");
                continue;
            }
            if (nutrient.Value != value) add(path + ".nutrients", "value_mismatch", $"Nutrient {key} evidence does not match the recipe value.");
            if (CatalogPolicyVocabulary.NutrientUnits.TryGetValue(key, out var expectedUnit) &&
                !string.Equals(nutrient.Unit, expectedUnit, StringComparison.Ordinal))
                add(path + ".nutrients", "unit_mismatch", $"Nutrient {key} requires unit {expectedUnit} per serving.");
            if (string.IsNullOrWhiteSpace(nutrient.Unit) || string.IsNullOrWhiteSpace(nutrient.Method) || string.IsNullOrWhiteSpace(nutrient.Calculation))
                add(path + ".nutrients", "required", $"Nutrient {key} needs unit, method and calculation.");
            if (nutrient.SourceIds is not { Length: > 0 }) add(path + ".nutrients", "required", $"Nutrient {key} needs at least one source.");
            foreach (var sourceId in nutrient.SourceIds ?? [])
                if (!HasCitation(sourceId, citations)) add(path + ".nutrients", "unknown_reference", $"Citation {sourceId} does not exist in the bundle.");

            decimal calculated = 0;
            var calculationComplete = true;
            foreach (var ingredient in recipe.Ingredients ?? [])
            {
                if (!ingredientEvidence.TryGetValue(ingredient.Code, out var item) ||
                    item.EdiblePortionFactor is null or <= 0 || item.YieldFactor is null or <= 0 ||
                    item.NutrientsPer100G is null || !item.NutrientsPer100G.TryGetValue(key, out var per100) || per100 < 0)
                {
                    add(path + ".nutrients", "calculation_input_missing", $"Ingredient {ingredient.Code} lacks a valid per-100-g value or factor for {key}.");
                    calculationComplete = false;
                    continue;
                }
                calculated += ingredient.Amount * per100 / 100 * item.EdiblePortionFactor.Value * item.YieldFactor.Value;
            }
            if (calculationComplete && Math.Round(calculated, 2) != value)
                add(path + ".nutrients", "calculation_mismatch", $"Recomputed nutrient {key} does not match the recipe value.");
        }
    }

    private static void ValidateRule(
        CatalogRuleVersion version,
        int index,
        IReadOnlyDictionary<Guid, CatalogRuleEvidence[]> evidenceById,
        CatalogCitation[] citations,
        Action<string, string, string> add)
    {
        var path = $"evidence.rules[{index}]";
        var rule = version.Payload;
        if (rule is null || !evidenceById.TryGetValue(rule.VersionId, out var entries) || entries.Length == 0)
        {
            add(path, "evidence_missing", "Disease rule release evidence is required.");
            return;
        }
        var evidence = entries[0];
        if ((evidence.UnresolvedItems ?? []).Any(x => !string.IsNullOrWhiteSpace(x)))
            add(path + ".unresolvedItems", "unresolved", "Disease rule has unresolved source or clinical-review items.");
        if (string.IsNullOrWhiteSpace(evidence.SourceLocator)) add(path + ".sourceLocator", "required", "Rule source locator is required.");
        if (evidence.SourceIds is not { Length: > 0 }) add(path + ".sourceIds", "required", "Rule evidence needs at least one source.");
        foreach (var sourceId in evidence.SourceIds ?? [])
            if (!HasCitation(sourceId, citations)) add(path + ".sourceIds", "unknown_reference", $"Citation {sourceId} does not exist in the bundle.");
    }

    private static CatalogCombinationCoverage CountCombinations(
        string scopeCode,
        string? conditionCode,
        CatalogRecipeVersion[] recipeVersions,
        IReadOnlyList<HealthFact> facts,
        IReadOnlyList<DietaryRule> rules)
    {
        var recipes = recipeVersions.Select(x => x.Payload).Where(x => x is not null).ToArray()!;
        var breakfasts = recipes.Where(x => x.MealType == "breakfast" && MealConstraintPolicy.ValidRecipe(x)).ToArray();
        var lunches = recipes.Where(x => x.MealType == "lunch" && MealConstraintPolicy.ValidRecipe(x)).ToArray();
        var dinners = recipes.Where(x => x.MealType == "dinner" && MealConstraintPolicy.ValidRecipe(x)).ToArray();
        var valid = 0;
        var usableBreakfasts = new HashSet<Guid>();
        var usableLunches = new HashSet<Guid>();
        var usableDinners = new HashSet<Guid>();
        foreach (var breakfast in breakfasts)
            foreach (var lunch in lunches)
                foreach (var dinner in dinners)
                    if (MealConstraintPolicy.Matches([breakfast, lunch, dinner], facts, rules))
                    {
                        valid++;
                        usableBreakfasts.Add(breakfast.VersionId);
                        usableLunches.Add(lunch.VersionId);
                        usableDinners.Add(dinner.VersionId);
                    }
        return new(scopeCode, conditionCode, usableBreakfasts.Count, usableLunches.Count, usableDinners.Count, valid);
    }

    private static bool HasCitation(string id, IEnumerable<CatalogCitation> citations) =>
        citations.Any(x => string.Equals(x.Id, id, StringComparison.Ordinal));

    private static void ValidateKnowledgeReview(
        CatalogKnowledgeReview? review,
        CatalogClinicalReview? clinicalReview,
        Action<string, string, string> add)
    {
        const string path = "evidence.knowledgeReview";
        if (review is null)
        {
            add(path, "knowledge_review_required", "A reviewed candidate graph authorization is required before release.");
            return;
        }
        if (review.SchemaVersion != 1) add(path + ".schemaVersion", "unsupported", "Only knowledge review schema version 1 is supported.");
        if (!IsSha256(review.CandidateGraphSha256)) add(path + ".candidateGraphSha256", "invalid_digest", "Candidate graph SHA-256 is required.");
        if (!IsSha256(review.DecisionLedgerSha256)) add(path + ".decisionLedgerSha256", "invalid_digest", "Decision ledger SHA-256 is required.");
        if (!IsSha256(review.ReviewedGraphSha256)) add(path + ".reviewedGraphSha256", "invalid_digest", "Reviewed graph SHA-256 is required.");
        if (review.CandidateCount <= 0 || review.ApprovedCount != review.CandidateCount || review.PendingCount != 0 || review.RejectedCount != 0)
            add(path, "review_incomplete", "Every candidate must be approved with no pending or rejected item.");
        if (review.Decision != "approved") add(path + ".decision", "not_approved", "Knowledge review decision must be approved.");
        if (review.Sources is not { Length: > 0 }) add(path + ".sources", "required", "At least one permitted source revision is required.");
        else
        {
            foreach (var source in review.Sources)
            {
                if (source is null || string.IsNullOrWhiteSpace(source.SourceRevisionId))
                    add(path + ".sources", "required", "Every knowledge source needs a revision ID.");
                else if (source.RightsStatus != "permitted")
                    add(path + ".sources", "source_not_permitted", $"Source revision {source.SourceRevisionId} is not permitted.");
            }
            if (review.Sources.Where(x => x is not null).GroupBy(x => x.SourceRevisionId, StringComparer.Ordinal).Any(x => x.Count() > 1))
                add(path + ".sources", "duplicate", "Knowledge source revisions cannot be repeated.");
        }
        if (review.ClinicalReviewerIds is not { Length: > 0 } || review.ClinicalReviewerIds.Any(string.IsNullOrWhiteSpace))
            add(path + ".clinicalReviewerIds", "required", "At least one clinical reviewer ID is required.");
        else if (!string.IsNullOrWhiteSpace(clinicalReview?.ReviewerId) &&
                 !review.ClinicalReviewerIds.Contains(clinicalReview.ReviewerId, StringComparer.Ordinal))
            add(path + ".clinicalReviewerIds", "reviewer_mismatch", "Clinical review must be bound to a reviewer in the candidate decision ledger.");
    }

    private static bool IsSha256(string? value) => !string.IsNullOrWhiteSpace(value) && Regex.IsMatch(value, "^[A-Fa-f0-9]{64}$");
}
