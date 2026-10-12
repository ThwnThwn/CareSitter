namespace CareSitter.Nutrition.Domain;

public sealed record RecipeIngredient(string Code, string Name, decimal Amount, string Unit, string Basis);
