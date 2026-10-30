using Microsoft.Extensions.Options;

namespace CareSitter.Nutrition.Infrastructure;

public sealed class MealGroundingOptions
{
    public const string SectionName = "MealGrounding";
    public const string ReleasedGraphMode = "released_graph";
    public const string OwnerAuthorizedCorpusDemoMode = "owner_authorized_corpus_demo";
    public const string OwnerAuthorizedGraphDemoMode = "owner_authorized_graph_demo";
    public bool Enabled { get; init; }
    public string Mode { get; init; } = ReleasedGraphMode;
    public string ManifestPath { get; init; } = "";
    public string ManifestSha256 { get; init; } = "";
    public string ReviewedGraphPath { get; init; } = "";
    public string ReviewedGraphSha256 { get; init; } = "";
    public string DemoGraphPath { get; init; } = "";
    public string DemoGraphSha256 { get; init; } = "";
    public string DemoAuthorizationPath { get; init; } = "";
    public string DemoAuthorizationSha256 { get; init; } = "";
    public string CorpusPath { get; init; } = "";
    public string CorpusSha256 { get; init; } = "";
    public int TopK { get; init; } = 5;
}

internal sealed class MealGroundingOptionsValidator : IValidateOptions<MealGroundingOptions>
{
    public ValidateOptionsResult Validate(string? name, MealGroundingOptions options)
    {
        if (!options.Enabled) return ValidateOptionsResult.Success;
        if (options.TopK is < 1 or > 10)
            return ValidateOptionsResult.Fail("MealGrounding:TopK must be between 1 and 10.");
        if (options.Mode is not (MealGroundingOptions.ReleasedGraphMode or
            MealGroundingOptions.OwnerAuthorizedCorpusDemoMode or MealGroundingOptions.OwnerAuthorizedGraphDemoMode))
            return ValidateOptionsResult.Fail("MealGrounding:Mode is not supported.");
        var bindings = new List<(string Key, string Path, string Hash)>
        {
            ("Corpus", options.CorpusPath, options.CorpusSha256)
        };
        if (options.Mode == MealGroundingOptions.ReleasedGraphMode)
        {
            bindings.Add(("Manifest", options.ManifestPath, options.ManifestSha256));
            bindings.Add(("ReviewedGraph", options.ReviewedGraphPath, options.ReviewedGraphSha256));
        }
        else
        {
            bindings.Add(("DemoAuthorization", options.DemoAuthorizationPath,
                options.DemoAuthorizationSha256));
            if (options.Mode == MealGroundingOptions.OwnerAuthorizedGraphDemoMode)
                bindings.Add(("DemoGraph", options.DemoGraphPath, options.DemoGraphSha256));
        }
        foreach (var (key, path, hash) in bindings)
        {
            if (!Path.IsPathFullyQualified(path) || hash.Length != 64 || !hash.All(Uri.IsHexDigit))
                return ValidateOptionsResult.Fail($"MealGrounding:{key} requires an absolute path and SHA-256 digest.");
        }
        return ValidateOptionsResult.Success;
    }
}
