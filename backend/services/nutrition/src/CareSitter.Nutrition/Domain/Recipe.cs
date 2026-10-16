using System.Text.Json.Serialization;

namespace CareSitter.Nutrition.Domain;

public sealed record Recipe(Guid VersionId, string Name, string MealType, decimal Servings,
    RecipeIngredient[] Ingredients, string[] Allergens, Dictionary<string, decimal?> Nutrients,
    string[] PreparationSteps, string[] Sources, bool AllergenDataComplete,
    [property: JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)] RecipeSource[]? SourceDetails = null);
