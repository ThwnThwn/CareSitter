using CareSitter.Nutrition.Application;

namespace CareSitter.Nutrition.Tests;

public sealed class CatalogAuditTests
{
    [Theory]
    [InlineData("catalog/drafts")]
    [InlineData("catalog/sources/nested")]
    public async Task Audit_refuses_output_inside_protected_catalog_directories(string output)
    {
        await Assert.ThrowsAsync<ArgumentException>(() => CatalogAudit.RunAsync(
            ["--bundle", "unused.json", "--output", output]));
    }

    [Fact]
    public void Audit_preserves_all_composition_and_incomplete_labels_for_human_review()
    {
        var recipe = CatalogFailClosedTests.Meal("breakfast") with
        {
            Name = "=Fixture,\"name\"", AllergenDataComplete = false, Allergens = ["SOY"],
            Ingredients = [new("SAUCE", "Fixture sauce", 5, "ml", "raw"), new("BROTH", "Fixture broth", 10, "ml", "cooked")],
            PreparationSteps = ["Add sauce and broth"], SourceRecipeNote = "Review hidden ingredients | <fixture>"
        };
        CatalogAudit.AuditRecipe[] rows = [new("fixture", recipe)];
        var before = NutritionJson.Write(recipe);
        var csv = CatalogAudit.Csv(rows);
        var markdown = CatalogAudit.Markdown(rows, ["fixture revision"]);
        Assert.Contains("\"'=Fixture,\"\"name\"\"\"", csv);
        foreach (var output in new[] { csv, markdown })
        {
            Assert.Contains("Fixture sauce", output); Assert.Contains("Fixture broth", output);
            Assert.Contains("SOY", output); Assert.Contains("False", output);
            Assert.Contains("Add sauce and broth", output);
        }
        Assert.Contains("&lt;fixture&gt;", markdown);
        Assert.Equal(before, NutritionJson.Write(recipe));
    }
}
