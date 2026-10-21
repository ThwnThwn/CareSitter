using CareSitter.Nutrition.Application;
using CareSitter.Nutrition.Application.Catalog;
using CareSitter.Nutrition.Infrastructure;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.FileProviders;
using Microsoft.Extensions.Hosting;

namespace CareSitter.Nutrition.Tests;

public sealed class LocalDemoCatalogTests
{
    [Fact]
    public void Prepare_remaps_identity_labels_recipes_and_is_deterministic()
    {
        var fixture = Baseline();

        var first = CatalogLocalDemoPolicy.Prepare(fixture);
        var second = CatalogLocalDemoPolicy.Prepare(fixture);

        Assert.True(first.IsValid);
        Assert.Equal("adult-hypertension-pilot-local-demo", first.Bundle!.PackageKey);
        Assert.Empty(first.Bundle.Rules);
        Assert.All(first.Bundle.Recipes, recipe => Assert.StartsWith("[DEMO] ", recipe.Payload.Name, StringComparison.Ordinal));
        Assert.NotEqual(fixture.Recipes[0].RecipeId, first.Bundle.Recipes[0].RecipeId);
        Assert.NotEqual(fixture.Recipes[0].Payload.VersionId, first.Bundle.Recipes[0].Payload.VersionId);
        Assert.Equal(NutritionJson.Write(first.Bundle), NutritionJson.Write(second.Bundle));
        Assert.True(CatalogBundleValidator.Validate(first.Bundle).IsValid);
    }

    [Fact]
    public void Prepare_rejects_disease_scopes_and_rules()
    {
        var result = CatalogLocalDemoPolicy.Prepare(CatalogBundleTests.Bundle());

        Assert.False(result.IsValid);
        Assert.Contains(result.Issues, issue => issue.Code == "demo_rules_forbidden");
        Assert.Contains(result.Issues, issue => issue.Code == "demo_conditions_forbidden");
    }

    [Fact]
    public void Options_reject_enabling_demo_outside_development()
    {
        var configuration = new ConfigurationBuilder().AddInMemoryCollection(new Dictionary<string, string?>
        {
            ["NutritionCatalog:LocalDemoEnabled"] = "true"
        }).Build();

        Assert.Throws<InvalidOperationException>(() => LocalDemoCatalogOptions.From(configuration, new Environment("Production")));
    }

    private static CatalogBundle Baseline()
    {
        var source = CatalogBundleTests.Bundle();
        return source with
        {
            SupportedScopes = [source.SupportedScopes[0] with { ConditionCodes = [] }],
            Rules = []
        };
    }

    private sealed class Environment(string name) : IHostEnvironment
    {
        public string EnvironmentName { get; set; } = name;
        public string ApplicationName { get; set; } = "CareSitter.Nutrition.Tests";
        public string ContentRootPath { get; set; } = AppContext.BaseDirectory;
        public IFileProvider ContentRootFileProvider { get; set; } = new NullFileProvider();
    }
}
