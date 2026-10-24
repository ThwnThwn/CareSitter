using CareSitter.Nutrition.Application;
using CareSitter.Nutrition.Application.Catalog;

namespace CareSitter.Nutrition.Tests;

public sealed class BookDemoCatalogTests
{
    [Fact]
    public async Task Book_demo_bundle_is_a_valid_balanced_source_backed_local_catalog()
    {
        var bundle = await LoadAsync();

        var validation = CatalogBundleValidator.Validate(bundle);

        Assert.True(
            validation.IsValid,
            string.Join(Environment.NewLine, validation.Issues.Select(issue => $"{issue.Path}: {issue.Code}")));
        Assert.Equal("adult-baseline-p2a-v1", bundle.PackageKey);
        Assert.Empty(bundle.Rules);
        Assert.All(bundle.SupportedScopes, scope => Assert.Empty(scope.ConditionCodes));
        Assert.Equal(12, bundle.Recipes.Length);
        Assert.Equal(4, bundle.Recipes.Count(recipe => recipe.Payload.MealType == "breakfast"));
        Assert.Equal(4, bundle.Recipes.Count(recipe => recipe.Payload.MealType == "lunch"));
        Assert.Equal(4, bundle.Recipes.Count(recipe => recipe.Payload.MealType == "dinner"));

        var citationIds = bundle.Citations.Select(citation => citation.Id).ToHashSet(StringComparer.Ordinal);
        Assert.All(bundle.Recipes, version =>
        {
            var recipe = version.Payload;
            Assert.StartsWith("https://", recipe.ImageUrl, StringComparison.Ordinal);
            Assert.False(string.IsNullOrWhiteSpace(recipe.ImageAlt));
            Assert.Equal(2, recipe.Sources.Length);
            Assert.Contains(recipe.Sources, source => source.StartsWith("BOOK_2019_", StringComparison.Ordinal));
            Assert.Contains("VIETNAM_FOOD_COMPOSITION_2017", recipe.Sources);
            Assert.All(recipe.Sources, source => Assert.Contains(source, citationIds));
            Assert.True(recipe.AllergenDataComplete);
        });
    }

    [Fact]
    public async Task Book_demo_bundle_prepares_deterministically_for_local_runtime()
    {
        var bundle = await LoadAsync();

        var first = CatalogLocalDemoPolicy.Prepare(bundle);
        var second = CatalogLocalDemoPolicy.Prepare(bundle);

        Assert.True(first.IsValid, string.Join(Environment.NewLine, first.Issues.Select(issue => issue.Message)));
        Assert.Equal("adult-baseline-p2a-v1-local-demo", first.Bundle!.PackageKey);
        Assert.Empty(first.Bundle.Rules);
        Assert.All(first.Bundle.Recipes, recipe =>
            Assert.StartsWith("[DEMO] ", recipe.Payload.Name, StringComparison.Ordinal));
        Assert.Equal(NutritionJson.Write(first.Bundle), NutritionJson.Write(second.Bundle));
    }

    private static async Task<CatalogBundle> LoadAsync()
    {
        var path = Path.Combine(
            ServiceArchitectureTests.FindRoot(),
            "catalog",
            "drafts",
            "adult-baseline-book-demo.bundle.json");
        return NutritionJson.Read<CatalogBundle>(await File.ReadAllTextAsync(path));
    }
}
