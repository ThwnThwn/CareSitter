namespace CareSitter.Nutrition.Domain;

public sealed record RecipeSource(string Id, string Title, string Organization, int Year,
    string? Edition, string? Chapter, string? PrintedPages, string? PdfPages,
    string Locator, string Reference, DateOnly VerifiedOn);
