using System.Text.RegularExpressions;

namespace CareSitter.Nutrition.Infrastructure;

internal sealed record LocalDemoCatalogOptions(bool Enabled, string PackageKey)
{
    public const string DefaultPackageKey = "adult-baseline-p2a-v1-local-demo";
    public static LocalDemoCatalogOptions Disabled { get; } = new(false, DefaultPackageKey);

    public static LocalDemoCatalogOptions From(IConfiguration configuration, IHostEnvironment environment)
    {
        var enabled = configuration.GetValue("NutritionCatalog:LocalDemoEnabled", false);
        var packageKey = configuration["NutritionCatalog:LocalDemoPackageKey"] ?? DefaultPackageKey;
        if (enabled && !environment.IsDevelopment())
            throw new InvalidOperationException("Nutrition local demo catalog can only be enabled in Development.");
        if (!Regex.IsMatch(packageKey, "^[a-z0-9]+(?:-[a-z0-9]+)*-local-demo$", RegexOptions.CultureInvariant))
            throw new InvalidOperationException("NutritionCatalog:LocalDemoPackageKey must be a lower-kebab key ending in -local-demo.");
        return new(enabled, packageKey);
    }
}
