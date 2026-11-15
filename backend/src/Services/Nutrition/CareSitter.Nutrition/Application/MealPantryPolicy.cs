using System.Text;
using CareSitter.Nutrition.Domain;

namespace CareSitter.Nutrition.Application;

public static class MealPantryPolicy
{
    public const int MaximumItems = 20;
    public const int MaximumLength = 80;
    public static bool Valid(IReadOnlyList<string>? values) => values is null ||
        values.Count <= MaximumItems && values.All(value => !string.IsNullOrWhiteSpace(value) &&
            value.Length <= MaximumLength && Canonical(value).Length >= 2);

    public static string[] Normalize(IEnumerable<string>? values) => (values ?? [])
        .Select(Canonical).Distinct(StringComparer.Ordinal).Order(StringComparer.Ordinal).ToArray();

    // Preserve Vietnamese accents and whole words: “cà” is not “cá”, “gà” is not “gạo”.
    // This is a preference signal, never an allergen or safety classifier.
    public static string[] Matches(Recipe recipe, IEnumerable<string>? available) => Normalize(available)
        .Where(value => recipe.Ingredients.Any(ingredient =>
            $" {Canonical(ingredient.Name)} ".Contains($" {value} ", StringComparison.Ordinal)))
        .ToArray();

    private static string Canonical(string value)
    {
        var words = new StringBuilder();
        foreach (var character in value.ToLowerInvariant().Normalize(NormalizationForm.FormC))
            words.Append(char.IsLetterOrDigit(character) ? character : ' ');
        return string.Join(' ', words.ToString().Split(' ', StringSplitOptions.RemoveEmptyEntries));
    }
}
