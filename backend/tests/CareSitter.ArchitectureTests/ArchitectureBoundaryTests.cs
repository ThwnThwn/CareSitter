using System.Text.RegularExpressions;

namespace CareSitter.ArchitectureTests;

public sealed class ArchitectureBoundaryTests
{
    private static readonly string RepositoryRoot = FindRepositoryRoot();
    private static readonly string ModulesRoot = Path.Combine(
        RepositoryRoot, "backend", "caresitter-be", "Modules");

    private static readonly string[] ForbiddenDomainDependencies =
    {
        "Microsoft.EntityFrameworkCore",
        "Microsoft.AspNetCore",
        "CareSitter.Infrastructure",
        ".Application",
        ".Infrastructure",
        ".Controllers"
    };

    // These sets intentionally remain empty. Any new entry needs a separate ADR.
    private static readonly HashSet<string> ExistingApplicationInfrastructureDebt = new(StringComparer.OrdinalIgnoreCase)
    {
    };

    private static readonly HashSet<string> ExistingControllerInfrastructureDebt = new(StringComparer.OrdinalIgnoreCase)
    {
    };

    [Fact]
    public void Domain_source_does_not_depend_on_outer_layers_or_frameworks()
    {
        var violations = SourceFiles("Domain")
            .SelectMany(path => ForbiddenDomainDependencies
                .Where(token => File.ReadAllText(path).Contains(token, StringComparison.Ordinal))
                .Select(token => $"{Relative(path)} -> {token}"))
            .ToArray();

        Assert.True(violations.Length == 0,
            "Domain dependency violations:" + Environment.NewLine + string.Join(Environment.NewLine, violations));
    }

    [Fact]
    public void Application_infrastructure_debt_can_only_decrease()
    {
        AssertNoNewDebt(
            FilesUnderLayer("Application")
                .Where(ReferencesInfrastructure)
                .Select(Relative),
            ExistingApplicationInfrastructureDebt,
            "Application -> Infrastructure");
    }

    [Fact]
    public void Controller_infrastructure_debt_can_only_decrease()
    {
        AssertNoNewDebt(
            FilesUnderLayer("Controllers")
                .Where(ReferencesInfrastructure)
                .Select(Relative),
            ExistingControllerInfrastructureDebt,
            "Controller -> Infrastructure");
    }

    [Fact]
    public void Clean_catalog_application_does_not_depend_on_framework_adapters()
    {
        var catalogApplication = Path.Combine(ModulesRoot, "Catalog", "Application");
        var forbidden = new[]
        {
            "Microsoft.EntityFrameworkCore",
            "Microsoft.AspNetCore",
            "Microsoft.Extensions.Caching",
            "Microsoft.Extensions.Configuration",
            "System.Net.Http",
            "DbContext"
        };

        var violations = Directory.EnumerateFiles(catalogApplication, "*.cs", SearchOption.AllDirectories)
            .SelectMany(path => forbidden
                .Where(token => File.ReadAllText(path).Contains(token, StringComparison.Ordinal))
                .Select(token => $"{Relative(path)} -> {token}"))
            .ToArray();

        Assert.True(violations.Length == 0,
            "Catalog Application adapter violations:" + Environment.NewLine +
            string.Join(Environment.NewLine, violations));
    }

    [Fact]
    public void Clean_people_application_does_not_depend_on_framework_adapters()
    {
        var peopleApplication = Path.Combine(ModulesRoot, "People", "Application");
        var forbidden = new[]
        {
            "Microsoft.EntityFrameworkCore",
            "Microsoft.AspNetCore",
            "Microsoft.Extensions.Caching",
            "Microsoft.Extensions.Configuration",
            "System.Net.Http",
            "DbContext"
        };

        var violations = Directory.EnumerateFiles(peopleApplication, "*.cs", SearchOption.AllDirectories)
            .SelectMany(path => forbidden
                .Where(token => File.ReadAllText(path).Contains(token, StringComparison.Ordinal))
                .Select(token => $"{Relative(path)} -> {token}"))
            .ToArray();

        Assert.True(violations.Length == 0,
            "People Application adapter violations:" + Environment.NewLine +
            string.Join(Environment.NewLine, violations));
    }

    [Fact]
    public void Clean_support_application_does_not_depend_on_framework_adapters()
    {
        var supportApplication = Path.Combine(ModulesRoot, "Support", "Application");
        var forbidden = new[]
        {
            "Microsoft.EntityFrameworkCore",
            "Microsoft.AspNetCore",
            "Microsoft.Extensions.Caching",
            "Microsoft.Extensions.Configuration",
            "System.Net.Http",
            "DbContext"
        };

        var violations = Directory.EnumerateFiles(supportApplication, "*.cs", SearchOption.AllDirectories)
            .SelectMany(path => forbidden
                .Where(token => File.ReadAllText(path).Contains(token, StringComparison.Ordinal))
                .Select(token => $"{Relative(path)} -> {token}"))
            .ToArray();

        Assert.True(violations.Length == 0,
            "Support Application adapter violations:" + Environment.NewLine +
            string.Join(Environment.NewLine, violations));
    }

    [Fact]
    public void Clean_identity_application_does_not_depend_on_framework_adapters()
    {
        var identityApplication = Path.Combine(ModulesRoot, "Identity", "Application");
        var forbidden = new[]
        {
            "Microsoft.EntityFrameworkCore",
            "Microsoft.AspNetCore",
            "Microsoft.Extensions.Caching",
            "Microsoft.Extensions.Configuration",
            "System.Net.Http",
            "DbContext"
        };

        var violations = Directory.EnumerateFiles(identityApplication, "*.cs", SearchOption.AllDirectories)
            .SelectMany(path => forbidden
                .Where(token => File.ReadAllText(path).Contains(token, StringComparison.Ordinal))
                .Select(token => $"{Relative(path)} -> {token}"))
            .ToArray();

        Assert.True(violations.Length == 0,
            "Identity Application adapter violations:" + Environment.NewLine +
            string.Join(Environment.NewLine, violations));
    }

    [Fact]
    public void Clean_payments_application_does_not_depend_on_framework_adapters()
    {
        var paymentsApplication = Path.Combine(ModulesRoot, "Payments", "Application");
        var forbidden = new[]
        {
            "Microsoft.EntityFrameworkCore",
            "Microsoft.AspNetCore",
            "Microsoft.Extensions.Caching",
            "Microsoft.Extensions.Configuration",
            "System.Net.Http",
            "DbContext"
        };

        var violations = Directory.EnumerateFiles(paymentsApplication, "*.cs", SearchOption.AllDirectories)
            .SelectMany(path => forbidden
                .Where(token => File.ReadAllText(path).Contains(token, StringComparison.Ordinal))
                .Select(token => $"{Relative(path)} -> {token}"))
            .ToArray();

        Assert.True(violations.Length == 0,
            "Payments Application adapter violations:" + Environment.NewLine +
            string.Join(Environment.NewLine, violations));
    }

    [Fact]
    public void Clean_booking_application_does_not_depend_on_framework_adapters()
    {
        var bookingApplication = Path.Combine(ModulesRoot, "Booking", "Application");
        var forbidden = new[]
        {
            "Microsoft.EntityFrameworkCore",
            "Microsoft.AspNetCore",
            "Microsoft.Extensions.Caching",
            "Microsoft.Extensions.Configuration",
            "System.Net.Http",
            "DbContext"
        };

        var violations = Directory.EnumerateFiles(bookingApplication, "*.cs", SearchOption.AllDirectories)
            .SelectMany(path => forbidden
                .Where(token => File.ReadAllText(path).Contains(token, StringComparison.Ordinal))
                .Select(token => $"{Relative(path)} -> {token}"))
            .ToArray();

        Assert.True(violations.Length == 0,
            "Booking Application adapter violations:" + Environment.NewLine +
            string.Join(Environment.NewLine, violations));
    }

    [Fact]
    public void Module_project_references_are_explicitly_ratcheted()
    {
        var allowed = new HashSet<string>(StringComparer.OrdinalIgnoreCase)
        {
        };

        var projectFiles = Directory.EnumerateFiles(ModulesRoot, "*.csproj", SearchOption.AllDirectories);
        var actual = new List<string>();
        foreach (var projectFile in projectFiles)
        {
            var source = Path.GetFileNameWithoutExtension(projectFile)
                .Replace("CareSitter.Modules.", string.Empty, StringComparison.OrdinalIgnoreCase);
            var contents = File.ReadAllText(projectFile);
            foreach (Match match in Regex.Matches(contents, @"Modules[\\/](?<target>[^\\/]+)[\\/]CareSitter\.Modules\.[^\""']+\.csproj"))
            {
                actual.Add($"{source}->{match.Groups["target"].Value}");
            }
        }

        AssertNoNewDebt(actual, allowed, "cross-module project reference");
    }

    private static IEnumerable<string> SourceFiles(string layer) =>
        Directory.EnumerateFiles(ModulesRoot, "*.cs", SearchOption.AllDirectories)
            .Where(path => path.Split(Path.DirectorySeparatorChar)
                .Contains(layer, StringComparer.OrdinalIgnoreCase));

    private static IEnumerable<string> FilesUnderLayer(string layer) => SourceFiles(layer)
        .Where(path => !path.Contains($"{Path.DirectorySeparatorChar}bin{Path.DirectorySeparatorChar}", StringComparison.OrdinalIgnoreCase))
        .Where(path => !path.Contains($"{Path.DirectorySeparatorChar}obj{Path.DirectorySeparatorChar}", StringComparison.OrdinalIgnoreCase));

    private static bool ReferencesInfrastructure(string path) =>
        Regex.IsMatch(File.ReadAllText(path), @"using CareSitter\.(Infrastructure|Modules\.[^.]+\.Infrastructure)");

    private static void AssertNoNewDebt(
        IEnumerable<string> actualDebt,
        IReadOnlySet<string> allowedDebt,
        string rule)
    {
        var unexpected = actualDebt
            .Distinct(StringComparer.OrdinalIgnoreCase)
            .Where(path => !allowedDebt.Contains(path))
            .OrderBy(path => path)
            .ToArray();

        Assert.True(unexpected.Length == 0,
            $"New {rule} debt is forbidden:" + Environment.NewLine + string.Join(Environment.NewLine, unexpected));
    }

    private static string Relative(string path) => Path.GetRelativePath(ModulesRoot, path)
        .Replace(Path.DirectorySeparatorChar, '/');

    private static string FindRepositoryRoot()
    {
        var current = new DirectoryInfo(AppContext.BaseDirectory);
        while (current is not null)
        {
            if (Directory.Exists(Path.Combine(current.FullName, "backend", "caresitter-be", "Modules")))
                return current.FullName;
            current = current.Parent;
        }

        throw new DirectoryNotFoundException("Could not locate the CareSitter repository root.");
    }
}
