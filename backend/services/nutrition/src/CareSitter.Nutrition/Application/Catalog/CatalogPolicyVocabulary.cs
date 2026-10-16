namespace CareSitter.Nutrition.Application.Catalog;

public static class CatalogPolicyVocabulary
{
    public const int SchemaVersion = 2;
    public const string AdultPopulation = "adult";
    public const string ReportedNoneMedicationPolicy = "reported_none_only";
    public const string HealthProfileEvidenceSource = "health_profile";

    public static readonly IReadOnlySet<string> MealTypes = new HashSet<string>(StringComparer.Ordinal)
    {
        "breakfast", "lunch", "dinner"
    };

    public static readonly IReadOnlySet<int> SupportedSchemaVersions = new HashSet<int> { 1, SchemaVersion };

    public static readonly IReadOnlySet<string> NutrientConstraintScopes = new HashSet<string>(StringComparer.Ordinal)
    {
        "daily", "meal"
    };

    public static readonly IReadOnlySet<string> ConceptKinds = new HashSet<string>(StringComparer.Ordinal)
    {
        "condition", "food_allergy", "ingredient"
    };

    public static readonly IReadOnlySet<string> PrerequisiteFields = new HashSet<string>(StringComparer.Ordinal)
    {
        "conditionsStatus", "medicationsStatus", "feedingRoute", "swallowingStatus",
        "fluidRestriction", "electrolyteRestriction"
    };

    public static readonly IReadOnlySet<string> PrerequisiteOperators = new HashSet<string>(StringComparer.Ordinal)
    {
        "known", "equals", "one_of"
    };

    public static readonly IReadOnlySet<string> RequiredBlockedSpecialNeeds = new HashSet<string>(StringComparer.Ordinal)
    {
        "KIDNEY_DISEASE", "DYSPHAGIA", "TUBE_FEEDING", "FLUID_RESTRICTION", "ELECTROLYTE_RESTRICTION"
    };

    // These conditions require a clinician-managed nutrition plan. Recognizing their
    // concepts in the catalog must never enable automatic meal recommendations.
    public static readonly IReadOnlySet<string> ClinicianOnlyConditions = new HashSet<string>(StringComparer.Ordinal)
    {
        "MALNUTRITION", "SARCOPENIA", "KIDNEY_DISEASE", "HEART_FAILURE", "CANCER", "STROKE"
    };

    // Amounts in a recipe refer to one standardized serving. Release evidence must
    // report the unit encoded by the nutrient key, including newly collected lipids.
    public static readonly IReadOnlyDictionary<string, string> NutrientUnits = new Dictionary<string, string>(StringComparer.Ordinal)
    {
        ["energy_kcal"] = "kcal",
        ["carbohydrate_g"] = "g",
        ["protein_g"] = "g",
        ["fat_g"] = "g",
        ["saturated_fat_g"] = "g",
        ["trans_fat_g"] = "g",
        ["cholesterol_mg"] = "mg",
        ["fiber_g"] = "g",
        ["free_sugar_g"] = "g",
        ["sodium_mg"] = "mg",
        ["calcium_mg"] = "mg",
        ["vitamin_d_ug"] = "ug",
        ["potassium_mg"] = "mg",
        ["phosphorus_mg"] = "mg",
        ["fluid_ml"] = "ml",
        ["alcohol_g"] = "g",
        ["purine_mg"] = "mg"
    };
}
