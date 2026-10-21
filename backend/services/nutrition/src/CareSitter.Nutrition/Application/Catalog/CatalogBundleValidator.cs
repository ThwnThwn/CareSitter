using System.Text.RegularExpressions;
using CareSitter.Nutrition.Domain;

namespace CareSitter.Nutrition.Application.Catalog;

public static class CatalogBundleValidator
{
    public static CatalogValidationResult Validate(CatalogBundle? bundle)
    {
        var issues = new List<CatalogValidationIssue>();
        void Add(string path, string code, string message) => issues.Add(new(path, code, message));
        if (bundle is null)
        {
            Add("$", "required", "Catalog bundle is required.");
            return new(issues);
        }

        if (!CatalogPolicyVocabulary.SupportedSchemaVersions.Contains(bundle.SchemaVersion))
            Add("schemaVersion", "unsupported", $"Supported schema versions are {string.Join(", ", CatalogPolicyVocabulary.SupportedSchemaVersions.Order())}.");
        if (string.IsNullOrWhiteSpace(bundle.PackageKey) || !Regex.IsMatch(bundle.PackageKey, "^[a-z0-9]+(?:-[a-z0-9]+)*$"))
            Add("packageKey", "format", "Package key must use lower-case kebab-case.");

        var scopes = bundle.SupportedScopes ?? [];
        if (scopes.Length == 0) Add("supportedScopes", "required", "At least one supported scope is required.");
        for (var index = 0; index < scopes.Length; index++) ValidateScope(scopes[index], index, Add);

        var citations = bundle.Citations ?? [];
        if (citations.Length == 0) Add("citations", "required", "At least one citation is required.");
        var citationIds = Unique(citations.Select(x => x.Id), "citations", "id", Add);
        for (var index = 0; index < citations.Length; index++) ValidateCitation(citations[index], index, Add);

        var concepts = bundle.Concepts ?? [];
        var conceptCodes = Unique(concepts.Select(x => x.Code), "concepts", "code", Add);
        var conceptByCode = concepts.Where(x => !string.IsNullOrWhiteSpace(x.Code))
            .GroupBy(x => x.Code, StringComparer.Ordinal).ToDictionary(x => x.Key, x => x.First(), StringComparer.Ordinal);
        for (var index = 0; index < concepts.Length; index++) ValidateConcept(concepts[index], index, Add);

        var recipes = bundle.Recipes ?? [];
        if (recipes.Length == 0) Add("recipes", "required", "At least one recipe is required.");
        Unique(recipes.Select(x => x.RecipeId.ToString()), "recipes", "recipeId", Add, allowRepeated: true);
        Unique(recipes.Select(x => x.Payload?.VersionId.ToString() ?? string.Empty), "recipes", "payload.versionId", Add);
        var recipeVersions = new HashSet<(Guid Id, int Version)>();
        for (var index = 0; index < recipes.Length; index++)
        {
            var recipe = recipes[index];
            if (!recipeVersions.Add((recipe.RecipeId, recipe.Version))) Add($"recipes[{index}]", "duplicate_version", "Recipe ID and version must be unique.");
            ValidateRecipe(recipe, index, citationIds, conceptByCode, Add);
        }
        foreach (var mealType in CatalogPolicyVocabulary.MealTypes)
            if (!recipes.Any(x => x.Payload?.MealType == mealType)) Add("recipes", "meal_type_missing", $"A published bundle needs at least one {mealType} recipe.");

        var rules = bundle.Rules ?? [];
        Unique(rules.Select(x => x.Payload?.VersionId.ToString() ?? string.Empty), "rules", "payload.versionId", Add);
        var ruleVersions = new HashSet<(Guid Id, int Version)>();
        for (var index = 0; index < rules.Length; index++)
        {
            var rule = rules[index];
            if (!ruleVersions.Add((rule.RuleId, rule.Version))) Add($"rules[{index}]", "duplicate_version", "Rule ID and version must be unique.");
            ValidateRule(rule, index, bundle.SchemaVersion, citationIds, conceptByCode, recipes, Add);
        }

        var supportedConditions = scopes.SelectMany(x => x.ConditionCodes ?? []).ToHashSet(StringComparer.Ordinal);
        foreach (var rule in rules)
        {
            var payload = rule?.Payload;
            if (payload is not null && !supportedConditions.Contains(payload.ConditionCode))
                Add("supportedScopes", "condition_scope_missing", $"Condition {payload.ConditionCode} is not enabled by a supported scope.");
        }

        return new(issues);
    }

    private static void ValidateScope(CatalogSupportedScope? scope, int index, Action<string, string, string> add)
    {
        var path = $"supportedScopes[{index}]";
        if (scope is null) { add(path, "required", "Scope is required."); return; }
        Required(scope.Code, path + ".code", add);
        if (scope.Population != CatalogPolicyVocabulary.AdultPopulation) add(path + ".population", "unsupported", "P0 supports adult profiles only.");
        if (scope.MedicationPolicy != CatalogPolicyVocabulary.ReportedNoneMedicationPolicy) add(path + ".medicationPolicy", "unsupported", "P0 requires medicationsStatus=reported_none.");
        var blocked = (scope.BlockedSpecialNeeds ?? []).ToHashSet(StringComparer.Ordinal);
        foreach (var code in CatalogPolicyVocabulary.RequiredBlockedSpecialNeeds)
            if (!blocked.Contains(code)) add(path + ".blockedSpecialNeeds", "missing_safety_block", $"Safety block {code} is required.");
        foreach (var code in scope.ConditionCodes ?? []) Code(code, path + ".conditionCodes", add);
        foreach (var code in scope.ConditionCodes ?? [])
            if (CatalogPolicyVocabulary.ClinicianOnlyConditions.Contains(code))
                add(path + ".conditionCodes", "clinician_only_condition", $"Condition {code} must remain under professional guidance.");
    }

    private static void ValidateCitation(CatalogCitation? citation, int index, Action<string, string, string> add)
    {
        var path = $"citations[{index}]";
        if (citation is null) { add(path, "required", "Citation is required."); return; }
        Code(citation.Id, path + ".id", add);
        Required(citation.Title, path + ".title", add);
        Required(citation.Organization, path + ".organization", add);
        if (citation.Year is < 1900 or > 2100) add(path + ".year", "range", "Citation year is outside the accepted range.");
        Required(citation.Locator, path + ".locator", add);
        Required(citation.Reference, path + ".reference", add);
        if (citation.VerifiedOn == default) add(path + ".verifiedOn", "required", "Verification date is required.");
        if (citation.FileSha256 is { Length: > 0 } hash && !Regex.IsMatch(hash, "^[A-Fa-f0-9]{64}$")) add(path + ".fileSha256", "format", "File SHA-256 must contain 64 hexadecimal characters.");
    }

    private static void ValidateConcept(NutritionConcept? concept, int index, Action<string, string, string> add)
    {
        var path = $"concepts[{index}]";
        if (concept is null) { add(path, "required", "Concept is required."); return; }
        Code(concept.Code, path + ".code", add);
        if (!CatalogPolicyVocabulary.ConceptKinds.Contains(concept.Kind)) add(path + ".kind", "unsupported", "Concept kind is not supported.");
        if (concept.Version <= 0) add(path + ".version", "range", "Concept version must be positive.");
        if (concept.Aliases is not { Length: > 0 } || concept.Aliases.Any(string.IsNullOrWhiteSpace)) add(path + ".aliases", "required", "At least one non-empty alias is required.");
    }

    private static void ValidateRecipe(CatalogRecipeVersion? version, int index, IReadOnlySet<string> citations,
        IReadOnlyDictionary<string, NutritionConcept> concepts, Action<string, string, string> add)
    {
        var path = $"recipes[{index}]";
        if (version is null) { add(path, "required", "Recipe version is required."); return; }
        if (version.RecipeId == Guid.Empty) add(path + ".recipeId", "required", "Recipe ID is required.");
        if (version.Version <= 0) add(path + ".version", "range", "Recipe version must be positive.");
        var recipe = version.Payload;
        if (recipe is null) { add(path + ".payload", "required", "Recipe payload is required."); return; }
        if (recipe.VersionId == Guid.Empty) add(path + ".payload.versionId", "required", "Recipe version ID is required.");
        Required(recipe.Name, path + ".payload.name", add);
        if (!CatalogPolicyVocabulary.MealTypes.Contains(recipe.MealType)) add(path + ".payload.mealType", "unsupported", "Meal type must be breakfast, lunch or dinner.");
        if (recipe.Servings <= 0) add(path + ".payload.servings", "range", "Servings must be positive.");
        if (recipe.Ingredients is not { Length: > 0 }) add(path + ".payload.ingredients", "required", "At least one ingredient is required.");
        else for (var i = 0; i < recipe.Ingredients.Length; i++)
        {
            var ingredient = recipe.Ingredients[i]; var ingredientPath = path + $".payload.ingredients[{i}]";
            if (!concepts.TryGetValue(ingredient.Code, out var concept) || concept.Kind != "ingredient") add(ingredientPath + ".code", "unknown_reference", "Ingredient code must reference an ingredient concept.");
            Required(ingredient.Name, ingredientPath + ".name", add);
            if (ingredient.Amount <= 0) add(ingredientPath + ".amount", "range", "Ingredient amount must be positive.");
            Required(ingredient.Unit, ingredientPath + ".unit", add); Required(ingredient.Basis, ingredientPath + ".basis", add);
        }
        foreach (var allergen in recipe.Allergens ?? [])
            if (!concepts.TryGetValue(allergen, out var concept) || concept.Kind != "food_allergy") add(path + ".payload.allergens", "unknown_reference", $"Allergen {allergen} must reference a food_allergy concept.");
        if (!recipe.AllergenDataComplete) add(path + ".payload.allergenDataComplete", "required", "Published recipes require complete allergen data.");
        if (recipe.DietaryPatterns is { } patterns)
        {
            if (patterns.Distinct(StringComparer.Ordinal).Count() != patterns.Length)
                add(path + ".payload.dietaryPatterns", "duplicate", "Dietary patterns cannot be repeated.");
            foreach (var pattern in patterns)
                if (!CatalogPolicyVocabulary.DietaryPatterns.Contains(pattern))
                    add(path + ".payload.dietaryPatterns", "unsupported", $"Dietary pattern {pattern} is not supported.");
        }
        if (recipe.Nutrients is null || recipe.Nutrients.Count == 0) add(path + ".payload.nutrients", "required", "Nutrients are required.");
        else foreach (var nutrient in recipe.Nutrients)
            if (string.IsNullOrWhiteSpace(nutrient.Key) || nutrient.Value < 0) add(path + ".payload.nutrients", "invalid", "Nutrient names must be non-empty and values cannot be negative.");
        if (recipe.PreparationSteps is not { Length: > 0 } || recipe.PreparationSteps.Any(string.IsNullOrWhiteSpace)) add(path + ".payload.preparationSteps", "required", "Preparation steps are required.");
        ValidateImage(recipe, path + ".payload", add);
        ValidateSources(recipe.Sources, path + ".payload.sources", citations, add);
    }

    private static void ValidateImage(Recipe recipe, string path, Action<string, string, string> add)
    {
        if (string.IsNullOrWhiteSpace(recipe.ImageUrl))
        {
            if (!string.IsNullOrWhiteSpace(recipe.ImageAlt))
                add(path + ".imageUrl", "required", "An image URL is required when image alt text is provided.");
            return;
        }

        if (recipe.ImageUrl.Length > 2048)
            add(path + ".imageUrl", "length", "Image URL cannot exceed 2048 characters.");
        if (!Uri.TryCreate(recipe.ImageUrl, UriKind.Absolute, out var imageUri) ||
            !string.Equals(imageUri.Scheme, Uri.UriSchemeHttps, StringComparison.OrdinalIgnoreCase))
            add(path + ".imageUrl", "https_required", "Image URL must be an absolute HTTPS URL.");
        if (string.IsNullOrWhiteSpace(recipe.ImageAlt))
            add(path + ".imageAlt", "required", "Accessible image alt text is required when an image URL is provided.");
        else if (recipe.ImageAlt.Length > 200)
            add(path + ".imageAlt", "length", "Image alt text cannot exceed 200 characters.");
    }

    private static void ValidateRule(CatalogRuleVersion? version, int index, int schemaVersion, IReadOnlySet<string> citations,
        IReadOnlyDictionary<string, NutritionConcept> concepts, CatalogRecipeVersion[] recipes, Action<string, string, string> add)
    {
        var path = $"rules[{index}]";
        if (version is null) { add(path, "required", "Rule version is required."); return; }
        if (version.RuleId == Guid.Empty) add(path + ".ruleId", "required", "Rule ID is required.");
        if (version.Version <= 0) add(path + ".version", "range", "Rule version must be positive.");
        var rule = version.Payload;
        if (rule is null) { add(path + ".payload", "required", "Rule payload is required."); return; }
        if (rule.VersionId == Guid.Empty) add(path + ".payload.versionId", "required", "Rule version ID is required.");
        if (!concepts.TryGetValue(rule.ConditionCode, out var condition) || condition.Kind != "condition") add(path + ".payload.conditionCode", "unknown_reference", "Condition code must reference a condition concept.");
        if (CatalogPolicyVocabulary.ClinicianOnlyConditions.Contains(rule.ConditionCode))
            add(path + ".payload.conditionCode", "clinician_only_condition", "This condition requires professional guidance and cannot be published as an automatic rule.");
        var prerequisites = rule.Prerequisites ?? [];
        for (var i = 0; i < prerequisites.Length; i++) ValidatePrerequisite(prerequisites[i], path + $".payload.prerequisites[{i}]", add);
        foreach (var ingredient in rule.ExcludedIngredients ?? [])
            if (!concepts.TryGetValue(ingredient, out var concept) || concept.Kind != "ingredient") add(path + ".payload.excludedIngredients", "unknown_reference", $"Excluded ingredient {ingredient} is not in the dictionary.");
        if (rule.DailyMaximums is null) add(path + ".payload.dailyMaximums", "required", "Daily maximums are required.");
        else foreach (var maximum in rule.DailyMaximums)
        {
            if (string.IsNullOrWhiteSpace(maximum.Key) || maximum.Value < 0) add(path + ".payload.dailyMaximums", "invalid", "Daily maximum names must be non-empty and values cannot be negative.");
            if (recipes.Any(x => x.Payload?.Nutrients?.GetValueOrDefault(maximum.Key) is null)) add(path + ".payload.dailyMaximums", "nutrient_missing", $"Every recipe must provide nutrient {maximum.Key} used by a rule.");
        }
        if (schemaVersion == 1 && rule.NutrientConstraints is not null)
            add(path + ".payload.nutrientConstraints", "schema_mismatch", "Schema version 1 cannot contain nutrient constraints.");
        if (schemaVersion == 2 && rule.NutrientConstraints is null)
            add(path + ".payload.nutrientConstraints", "required", "Schema version 2 requires a nutrient constraints array.");
        var constraintKeys = new HashSet<(string NutrientKey, string Scope, string? MealType)>();
        foreach (var (constraint, constraintIndex) in (rule.NutrientConstraints ?? []).Select((value, valueIndex) => (value, valueIndex)))
        {
            var constraintPath = path + $".payload.nutrientConstraints[{constraintIndex}]";
            if (constraint is null)
            {
                add(constraintPath, "required", "Nutrient constraint is required.");
                continue;
            }
            if (string.IsNullOrWhiteSpace(constraint.NutrientKey)) add(constraintPath + ".nutrientKey", "required", "Nutrient key is required.");
            if (!CatalogPolicyVocabulary.NutrientConstraintScopes.Contains(constraint.Scope))
                add(constraintPath + ".scope", "unsupported", "Constraint scope must be daily or meal.");
            if (constraint.Scope == "daily" && constraint.MealType is not null)
                add(constraintPath + ".mealType", "invalid", "A daily constraint cannot select a meal type.");
            if (constraint.Scope == "meal" && !CatalogPolicyVocabulary.MealTypes.Contains(constraint.MealType ?? string.Empty))
                add(constraintPath + ".mealType", "unsupported", "A meal constraint requires breakfast, lunch or dinner.");
            if (constraint.Minimum is null && constraint.Maximum is null)
                add(constraintPath, "range_required", "A nutrient constraint needs a minimum, a maximum or both.");
            if (constraint.Minimum is < 0 || constraint.Maximum is < 0)
                add(constraintPath, "range", "Nutrient constraint bounds cannot be negative.");
            if (constraint.Minimum is { } minimum && constraint.Maximum is { } maximum && minimum > maximum)
                add(constraintPath, "range", "Nutrient constraint minimum cannot exceed its maximum.");
            if (!constraintKeys.Add((constraint.NutrientKey, constraint.Scope, constraint.MealType)))
                add(constraintPath, "duplicate", "A rule cannot repeat the same nutrient, scope and meal type constraint.");

            var applicableRecipes = constraint.Scope == "meal"
                ? recipes.Where(x => x.Payload?.MealType == constraint.MealType)
                : recipes.AsEnumerable();
            if (applicableRecipes.Any(x => x.Payload?.Nutrients?.GetValueOrDefault(constraint.NutrientKey) is null))
                add(constraintPath + ".nutrientKey", "nutrient_missing", $"Every applicable recipe must provide nutrient {constraint.NutrientKey} used by a rule.");
        }
        ValidateSources(rule.Sources, path + ".payload.sources", citations, add);
    }

    public static bool IsSupported(RulePrerequisite? prerequisite)
    {
        if (prerequisite is null || !CatalogPolicyVocabulary.PrerequisiteFields.Contains(prerequisite.Field) ||
            !CatalogPolicyVocabulary.PrerequisiteOperators.Contains(prerequisite.Operator) ||
            prerequisite.EvidenceSource != CatalogPolicyVocabulary.HealthProfileEvidenceSource || prerequisite.Unit is not null || prerequisite.MaxAgeDays is not null) return false;
        var values = prerequisite.Values ?? [];
        return prerequisite.Operator == "known" ? values.Length == 0 : values.Length > 0 && values.All(x => !string.IsNullOrWhiteSpace(x));
    }

    private static void ValidatePrerequisite(RulePrerequisite? prerequisite, string path, Action<string, string, string> add)
    {
        if (!IsSupported(prerequisite)) add(path, "unsupported", "Prerequisite cannot be evaluated by the current structured-profile engine.");
    }

    private static void ValidateSources(string[]? sources, string path, IReadOnlySet<string> citations, Action<string, string, string> add)
    {
        if (sources is not { Length: > 0 }) { add(path, "required", "At least one citation reference is required."); return; }
        foreach (var source in sources)
            if (!citations.Contains(source)) add(path, "unknown_reference", $"Citation {source} does not exist in the bundle.");
    }

    private static HashSet<string> Unique(IEnumerable<string?> values, string path, string field,
        Action<string, string, string> add, bool allowRepeated = false)
    {
        var seen = new HashSet<string>(StringComparer.Ordinal); var index = 0;
        foreach (var value in values)
        {
            if (string.IsNullOrWhiteSpace(value)) add($"{path}[{index}].{field}", "required", $"{field} is required.");
            else if (!seen.Add(value) && !allowRepeated) add($"{path}[{index}].{field}", "duplicate", $"{field} must be unique.");
            index++;
        }
        return seen;
    }

    private static void Required(string? value, string path, Action<string, string, string> add)
    { if (string.IsNullOrWhiteSpace(value)) add(path, "required", "Value is required."); }

    private static void Code(string? value, string path, Action<string, string, string> add)
    { if (string.IsNullOrWhiteSpace(value) || !Regex.IsMatch(value, "^[A-Z][A-Z0-9_]*$")) add(path, "format", "Code must use upper snake case."); }
}
