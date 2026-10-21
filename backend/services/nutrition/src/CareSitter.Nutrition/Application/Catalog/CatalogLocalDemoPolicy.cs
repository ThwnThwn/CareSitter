using System.Security.Cryptography;
using System.Text;

namespace CareSitter.Nutrition.Application.Catalog;

public sealed record CatalogLocalDemoPreparation(
    CatalogBundle? Bundle,
    IReadOnlyList<CatalogValidationIssue> Issues)
{
    public bool IsValid => Bundle is not null && Issues.Count == 0;
}

public static class CatalogLocalDemoPolicy
{
    private const string PackageSuffix = "-local-demo";
    private const string NamePrefix = "[DEMO] ";

    public static CatalogLocalDemoPreparation Prepare(CatalogBundle source)
    {
        var issues = CatalogBundleValidator.Validate(source).Issues.ToList();
        if (source.Rules.Length > 0)
            issues.Add(new("rules", "demo_rules_forbidden", "Local demo catalogs cannot contain disease rules."));
        if (source.SupportedScopes.Any(scope => scope.ConditionCodes.Length > 0))
            issues.Add(new("supportedScopes", "demo_conditions_forbidden", "Local demo catalogs must use an adult baseline without disease conditions."));
        if (issues.Count > 0) return new(null, issues);

        var packageKey = source.PackageKey.EndsWith(PackageSuffix, StringComparison.Ordinal)
            ? source.PackageKey
            : source.PackageKey + PackageSuffix;
        var recipes = source.Recipes.Select(version => version with
        {
            RecipeId = DemoId("recipe", version.RecipeId),
            Payload = version.Payload with
            {
                VersionId = DemoId("recipe-version", version.Payload.VersionId),
                Name = version.Payload.Name.StartsWith(NamePrefix, StringComparison.Ordinal)
                    ? version.Payload.Name
                    : NamePrefix + version.Payload.Name
            }
        }).ToArray();
        var scopes = source.SupportedScopes.Select(scope => scope with
        {
            Code = scope.Code.EndsWith(PackageSuffix, StringComparison.Ordinal)
                ? scope.Code
                : scope.Code + PackageSuffix
        }).ToArray();
        var bundle = source with
        {
            PackageKey = packageKey,
            SupportedScopes = scopes,
            Recipes = recipes,
            Rules = []
        };
        var transformed = CatalogBundleValidator.Validate(bundle);
        return transformed.IsValid
            ? new(bundle, [])
            : new(null, transformed.Issues);
    }

    private static Guid DemoId(string kind, Guid source)
    {
        var hash = SHA256.HashData(Encoding.UTF8.GetBytes($"caresitter:nutrition:{kind}:local-demo:{source:D}"));
        hash[6] = (byte)((hash[6] & 0x0f) | 0x50);
        hash[8] = (byte)((hash[8] & 0x3f) | 0x80);
        return new Guid(hash.AsSpan(0, 16));
    }
}
