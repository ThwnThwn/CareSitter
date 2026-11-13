using CareSitter.Nutrition.Application;
using CareSitter.Nutrition.Application.Catalog;

namespace CareSitter.Nutrition.Tests;

public sealed class BookDemoCatalogTests
{
    [Theory]
    [InlineData("adult-baseline-book-demo.bundle.json")]
    [InlineData("adult-baseline-variety-demo.bundle.json")]
    public async Task Baseline_recognizes_kidney_disease_for_professional_routing(string fileName)
    {
        var path = Path.Combine(ServiceArchitectureTests.FindRoot(), "catalog", "drafts", fileName);
        var bundle = NutritionJson.Read<CatalogBundle>(await File.ReadAllTextAsync(path));
        Assert.Contains(bundle.Concepts, concept => concept.Code == "KIDNEY_DISEASE" &&
            concept.Kind == "condition");
        Assert.DoesNotContain(bundle.Rules, rule => rule.Payload.ConditionCode == "KIDNEY_DISEASE");
    }

    [Theory]
    [InlineData("adult-baseline-book-demo.bundle.json")]
    [InlineData("adult-baseline-variety-demo.bundle.json")]
    public async Task Unquantified_wood_ear_recipe_is_excluded_from_candidates(string fileName)
    {
        var path = Path.Combine(ServiceArchitectureTests.FindRoot(), "catalog", "drafts", fileName);
        var bundle = NutritionJson.Read<CatalogBundle>(await File.ReadAllTextAsync(path));
        var recipe = Assert.Single(bundle.Recipes.Where(version =>
            version.Payload.VersionId == Guid.Parse("11d4fb6b-e523-5728-9765-e90f604a8bab"))).Payload;

        Assert.False(recipe.AllergenDataComplete);
        Assert.False(MealConstraintPolicy.ValidRecipe(recipe));
        foreach (var mealType in new[] { "breakfast", "lunch", "dinner" })
            Assert.Contains(bundle.Recipes, version => version.Payload.MealType == mealType &&
                MealConstraintPolicy.ValidRecipe(version.Payload));
    }

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
            if (recipe.Name.Contains("sườn chua ngọt", StringComparison.Ordinal) ||
                recipe.VersionId == Guid.Parse("11d4fb6b-e523-5728-9765-e90f604a8bab")) Assert.False(recipe.AllergenDataComplete);
            else Assert.True(recipe.AllergenDataComplete);
            Assert.Contains("Sách không đề cập công thức", recipe.SourceRecipeNote ?? string.Empty, StringComparison.Ordinal);
        });
        AssertPeanutOilIsLabeled(bundle);
        AssertSupportedMeatAllergiesAreLabeled(bundle);
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

    [Fact]
    public async Task Expanded_demo_catalog_discloses_recipe_origin_and_provides_eligible_choices()
    {
        var path = Path.Combine(
            ServiceArchitectureTests.FindRoot(),
            "catalog",
            "drafts",
            "adult-baseline-variety-demo.bundle.json");
        var bundle = NutritionJson.Read<CatalogBundle>(await File.ReadAllTextAsync(path));

        var validation = CatalogBundleValidator.Validate(bundle);

        Assert.True(
            validation.IsValid,
            string.Join(Environment.NewLine, validation.Issues.Select(issue => $"{issue.Path}: {issue.Code}")));
        Assert.Equal(78, bundle.Recipes.Length);
        Assert.Equal(26, bundle.Recipes.Count(recipe => recipe.Payload.MealType == "breakfast"));
        Assert.Equal(26, bundle.Recipes.Count(recipe => recipe.Payload.MealType == "lunch"));
        Assert.Equal(26, bundle.Recipes.Count(recipe => recipe.Payload.MealType == "dinner"));
        Assert.Equal(57, bundle.Recipes.Count(recipe => MealConstraintPolicy.ValidRecipe(recipe.Payload)));
        Assert.Equal(20, bundle.Recipes.Count(recipe =>
            recipe.Payload.DietaryPatterns?.Contains("vegetarian", StringComparer.Ordinal) == true));
        Assert.All(bundle.Recipes, version =>
            Assert.False(string.IsNullOrWhiteSpace(version.Payload.SourceRecipeNote)));
        Assert.Equal(12, bundle.Recipes.Count(recipe =>
            recipe.Payload.Sources.Any(source => source.StartsWith("BOOK_2019_", StringComparison.Ordinal))));
        Assert.Equal(48, bundle.Recipes.Count(recipe =>
            recipe.Payload.Sources.Contains("CARESITTER_VARIETY_ADAPTATION_V2", StringComparer.Ordinal)));
        var homeMeals = bundle.Recipes.Where(recipe =>
            recipe.Payload.Sources.Contains("CARESITTER_HOME_MEALS_DEMO", StringComparer.Ordinal)).ToArray();
        Assert.Equal(18, homeMeals.Length);
        Assert.All(homeMeals, recipe => Assert.True(MealConstraintPolicy.ValidRecipe(recipe.Payload)));
        Assert.All(bundle.Recipes, version =>
        {
            var images = version.Payload.Images;
            Assert.NotNull(images);
            Assert.InRange(images.Length, 1, 3);
            Assert.Equal(images[0].Url, version.Payload.ImageUrl);
            Assert.All(images, image =>
            {
                Assert.StartsWith("https://res.cloudinary.com/", image.Url, StringComparison.Ordinal);
                Assert.Equal("https", new Uri(image.SourceUrl).Scheme);
                Assert.False(string.IsNullOrWhiteSpace(image.Attribution));
            });
        });
        var cookingReferences = bundle.Citations
            .Where(citation => citation.Id.StartsWith("MNMN_", StringComparison.Ordinal)).ToArray();
        Assert.Equal(2, cookingReferences.Length);
        Assert.All(cookingReferences, citation =>
        {
            Assert.Equal("Món Ngon Mỗi Ngày", citation.Title);
            Assert.Equal("Ajinomoto Việt Nam", citation.Organization);
            Assert.Equal("monngonmoingay.com", new Uri(citation.Reference).Host);
            var adapted = Assert.Single(homeMeals, version => version.Payload.Sources.Contains(citation.Id));
            Assert.True(MealConstraintPolicy.ValidRecipe(adapted.Payload));
            Assert.Contains("CareSitter điều chỉnh", adapted.Payload.SourceRecipeNote);
        });
        AssertPeanutOilIsLabeled(bundle);
        AssertSupportedMeatAllergiesAreLabeled(bundle);
    }

    private static void AssertPeanutOilIsLabeled(CatalogBundle bundle)
    {
        Assert.All(bundle.Recipes, version =>
        {
            var recipe = version.Payload;
            if (!recipe.Ingredients.Any(ingredient =>
                    string.Equals(ingredient.Code, "PEANUT_OIL", StringComparison.OrdinalIgnoreCase))) return;

            Assert.Contains("PEANUT", recipe.Allergens);
            Assert.All(recipe.Ingredients.Where(ingredient =>
                string.Equals(ingredient.Code, "PEANUT_OIL", StringComparison.OrdinalIgnoreCase)),
                ingredient => Assert.StartsWith("Dầu lạc", ingredient.Name, StringComparison.Ordinal));
        });
    }

    private static void AssertSupportedMeatAllergiesAreLabeled(CatalogBundle bundle)
    {
        var allergyConcepts = bundle.Concepts
            .Where(concept => concept.Kind == "food_allergy")
            .ToDictionary(concept => concept.Code, StringComparer.Ordinal);
        Assert.Contains("Bò", allergyConcepts["BEEF"].Aliases);
        Assert.Contains("Gà", allergyConcepts["CHICKEN"].Aliases);

        var ingredientAllergens = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase)
        {
            ["BEEF_LEAN_RAW"] = "BEEF",
            ["CHICKEN_RAW"] = "CHICKEN"
        };
        Assert.All(bundle.Recipes, version =>
        {
            foreach (var ingredient in version.Payload.Ingredients)
            {
                if (!ingredientAllergens.TryGetValue(ingredient.Code, out var allergen)) continue;
                Assert.Contains(allergen, version.Payload.Allergens);
            }
        });
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
