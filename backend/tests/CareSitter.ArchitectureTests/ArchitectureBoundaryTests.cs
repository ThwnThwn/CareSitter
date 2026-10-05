using System.Text.RegularExpressions;
using System.Xml.Linq;

namespace CareSitter.ArchitectureTests;

public sealed class ArchitectureBoundaryTests
{
    private static readonly string RepositoryRoot = FindRepositoryRoot();
    private static readonly string ModulesRoot = Path.Combine(
        RepositoryRoot, "backend", "caresitter-be", "Modules");
    private static readonly string ApiHostRoot = Path.Combine(
        RepositoryRoot, "backend", "caresitter-be", "ApiHost");

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

    private static readonly HashSet<string> ExistingApiHostModuleLayerDebt = new(StringComparer.OrdinalIgnoreCase)
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
    public void Every_module_application_is_free_of_framework_adapters()
    {
        var forbidden = new[]
        {
            "Microsoft.EntityFrameworkCore", "Microsoft.AspNetCore",
            "Microsoft.Extensions.Caching", "Microsoft.Extensions.Configuration",
            "System.Net.Http", "DbContext"
        };
        var violations = FilesUnderLayer("Application")
            .SelectMany(path => forbidden
                .Where(token => File.ReadAllText(path).Contains(token, StringComparison.Ordinal))
                .Select(token => $"{Relative(path)} -> {token}"))
            .ToArray();

        Assert.True(violations.Length == 0,
            "Application adapter violations:" + Environment.NewLine +
            string.Join(Environment.NewLine, violations));
    }

    [Fact]
    public void Every_module_has_its_own_registered_unit_test_project()
    {
        var solution = File.ReadAllText(Path.Combine(RepositoryRoot, "backend", "CareSitter.sln"));
        foreach (var module in Directory.EnumerateFiles(ModulesRoot, "CareSitter.Modules.*.csproj",
                     SearchOption.AllDirectories).Where(IsSourceFile))
        {
            var name = Path.GetFileNameWithoutExtension(module);
            var testDirectory = Path.Combine(RepositoryRoot, "backend", "tests", $"{name}.UnitTests");
            var testProject = Path.Combine(testDirectory, $"{name}.UnitTests.csproj");
            Assert.True(File.Exists(testProject), $"Missing unit test project: {testProject}");
            Assert.Contains($"{name}.UnitTests.csproj", solution);
            Assert.Contains(Directory.EnumerateFiles(testDirectory, "*.cs", SearchOption.AllDirectories)
                .Where(IsSourceFile), file => File.ReadAllText(file).Contains("[Fact]", StringComparison.Ordinal) ||
                    File.ReadAllText(file).Contains("[Theory]", StringComparison.Ordinal));
            Assert.Contains(ReadProjectReferences(File.ReadAllText(testProject)),
                include => include.Replace('\\', '/').EndsWith($"/{name}.csproj", StringComparison.Ordinal));
        }
    }

    [Fact]
    public void Each_contract_or_response_dto_has_its_own_file_without_handlers_or_ports()
    {
        var dtoFiles = FilesUnderLayer("Controllers")
            .Where(path => path.Split(Path.DirectorySeparatorChar).Contains("Contracts"))
            .Where(path => Path.GetFileNameWithoutExtension(path).EndsWith("Request", StringComparison.Ordinal) ||
                Path.GetFileNameWithoutExtension(path).EndsWith("Response", StringComparison.Ordinal))
            .Concat(FilesUnderLayer("Application")
                .Where(path => Path.GetFileNameWithoutExtension(path).EndsWith("Response", StringComparison.Ordinal) ||
                    Path.GetFileNameWithoutExtension(path).EndsWith("Dto", StringComparison.Ordinal)))
            .ToArray();
        Assert.NotEmpty(dtoFiles);
        var declaration = new Regex(
            @"(?m)^\s*(?:(?:public|internal|private|protected|sealed|static|abstract|partial|readonly)\s+)*" +
            @"(?:record(?:\s+(?:class|struct))?|class|interface|enum|struct)\s+(?<name>[A-Za-z_]\w*)");
        foreach (var file in dtoFiles)
        {
            var source = File.ReadAllText(file);
            var type = Assert.Single(declaration.Matches(source).Cast<Match>());
            Assert.Equal(Path.GetFileNameWithoutExtension(file), type.Groups["name"].Value);
            Assert.DoesNotMatch(@"\bIRequest(?:Handler)?\b|\binterface\s+|using\s+MediatR\s*;", source);
            Assert.DoesNotMatch(@"using\s+CareSitter\.Modules\.[^.]+\.Domain\s*;", source);
        }
    }

    [Fact]
    public void Controller_source_does_not_declare_request_or_response_types()
    {
        var violations = FilesUnderLayer("Controllers")
            .Where(file => !file.Split(Path.DirectorySeparatorChar).Contains("Contracts"))
            .Where(file =>
            Regex.IsMatch(File.ReadAllText(file),
                @"\b(?:record|class)\s+\w*(?:Request|Response)\b"))
            .Select(Relative).ToArray();
        Assert.True(violations.Length == 0, "Move HTTP DTOs into Controllers/Contracts: " + string.Join(", ", violations));
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
            foreach (var include in ReadProjectReferences(File.ReadAllText(projectFile)))
            {
                var target = ModuleReferenceTarget(include);
                if (target is not null) actual.Add($"{source}->{target}");
            }
        }

        AssertNoNewDebt(actual, allowed, "cross-module project reference");
    }

    [Theory]
    [InlineData(@"..\People\CareSitter.Modules.People.csproj", "People")]
    [InlineData("../People/CareSitter.Modules.People.csproj", "People")]
    [InlineData(@"..\..\Modules\Promotion\CareSitter.Modules.Promotion.csproj", "Promotion")]
    [InlineData(@"D:\repo\Modules\People\CareSitter.Modules.People.csproj", "People")]
    [InlineData("/repo/Modules/People/CareSitter.Modules.People.csproj", "People")]
    [InlineData(@"..\People\caresitter.modules.people.CSPROJ", "people")]
    [InlineData(@"  ..\People\CareSitter.Modules.People.csproj  ", "People")]
    [InlineData(@"..\..\Shared\CareSitter.Contracts\CareSitter.Contracts.csproj", null)]
    public void Project_reference_detection_handles_all_path_forms(string include, string? expected)
        => Assert.Equal(expected, ModuleReferenceTarget(include));

    [Theory]
    [InlineData("$(ModuleProject)")]
    [InlineData("../*/CareSitter.Modules.*.csproj")]
    [InlineData("../People/CareSitter.Modules.People.csproj;../Catalog/CareSitter.Modules.Catalog.csproj")]
    public void Dynamic_project_references_require_an_explicit_guard_change(string include)
        => Assert.Throws<InvalidDataException>(() => ModuleReferenceTarget(include));

    [Theory]
    [InlineData("")]
    [InlineData(" xmlns=\"http://schemas.microsoft.com/developer/msbuild/2003\"")]
    public void Project_reference_reader_uses_xml_and_not_comments(string xmlNamespace)
    {
        var xml = $"<Project{xmlNamespace}><!-- <ProjectReference Include='ignored'/> -->" +
            "<ItemGroup><ProjectReference Condition=\"false\" " +
            "Include='../People/CareSitter.Modules.People.csproj' /></ItemGroup></Project>";
        // Conditional references still count: another build configuration can activate them.
        Assert.Equal(new[] { "../People/CareSitter.Modules.People.csproj" }, ReadProjectReferences(xml));
    }

    [Fact]
    public void Sql_is_the_only_runtime_schema_migration_mechanism()
    {
        var runtimeRoot = Path.Combine(RepositoryRoot, "backend", "caresitter-be");
        var forbidden = new Regex(
            @"Microsoft\.EntityFrameworkCore\.Migrations|:\s*(?:Migration|ModelSnapshot)\b|" +
            @"\.Database\s*\.\s*(?:Migrate|MigrateAsync|EnsureCreated|EnsureCreatedAsync)\s*\(");
        var violations = Directory.EnumerateFiles(runtimeRoot, "*.cs", SearchOption.AllDirectories)
            .Where(IsSourceFile)
            .Where(path => forbidden.IsMatch(File.ReadAllText(path)))
            .Select(path => Path.GetRelativePath(runtimeRoot, path)).ToArray();
        Assert.True(violations.Length == 0,
            "Runtime EF schema management is forbidden; use init-db SQL: " + string.Join(", ", violations));

        foreach (var project in Directory.EnumerateFiles(runtimeRoot, "*.csproj", SearchOption.AllDirectories))
        {
            var xml = XDocument.Load(project);
            Assert.DoesNotContain(xml.Descendants().Where(x => x.Name.LocalName == "Compile"),
                x => ((string?)x.Attribute("Include") ?? "").Contains("legacy-ef-migrations",
                    StringComparison.OrdinalIgnoreCase));
        }
    }

    private static string[] ReadProjectReferences(string xml) => XDocument.Parse(xml)
        .Descendants().Where(x => x.Name.LocalName == "ProjectReference")
        .Select(x => (string?)x.Attribute("Include") ??
            throw new InvalidDataException("ProjectReference must have an explicit Include.")).ToArray();

    private static string? ModuleReferenceTarget(string include)
    {
        if (include.IndexOfAny(['$', '*', '?', ';']) >= 0)
            throw new InvalidDataException($"Dynamic ProjectReference is not covered by this guard: {include}");
        var filename = include.Trim().Replace('\\', '/').Split('/').Last();
        var match = Regex.Match(filename, @"^CareSitter\.Modules\.(?<target>[^.]+)\.csproj$",
            RegexOptions.IgnoreCase | RegexOptions.CultureInvariant);
        return match.Success ? match.Groups["target"].Value : null;
    }

    [Fact]
    public void Module_source_does_not_reference_another_module_namespace()
    {
        var violations = Directory.EnumerateFiles(ModulesRoot, "*.cs", SearchOption.AllDirectories)
            .Where(IsSourceFile)
            .SelectMany(path => Regex.Matches(File.ReadAllText(path),
                    @"using\s+CareSitter\.Modules\.(?<target>[^.]+)\.")
                .Select(match => new
                {
                    Path = path,
                    Source = Path.GetRelativePath(ModulesRoot, path)
                        .Split(Path.DirectorySeparatorChar)[0],
                    Target = match.Groups["target"].Value
                }))
            .Where(x => !x.Source.Equals(x.Target, StringComparison.OrdinalIgnoreCase))
            .Select(x => $"{Relative(x.Path)} -> {x.Target}")
            .Distinct(StringComparer.OrdinalIgnoreCase)
            .OrderBy(x => x)
            .ToArray();

        Assert.True(violations.Length == 0,
            "Cross-module namespace dependencies:" + Environment.NewLine +
            string.Join(Environment.NewLine, violations));
    }

    [Fact]
    public void Module_sql_does_not_access_another_module_schema()
    {
        var moduleSchemas = new HashSet<string>(
            new[] { "identity", "people", "catalog", "booking", "payments", "support", "promotion" },
            StringComparer.OrdinalIgnoreCase);
        var sqlReference = new Regex(
            @"\b(?:FROM|JOIN|UPDATE|INSERT\s+INTO|DELETE\s+FROM)\s+(?<schema>[a-z_]+)\.",
            RegexOptions.IgnoreCase | RegexOptions.CultureInvariant);

        var violations = Directory.EnumerateFiles(ModulesRoot, "*.cs", SearchOption.AllDirectories)
            .Where(IsSourceFile)
            .SelectMany(path => sqlReference.Matches(File.ReadAllText(path))
                .Select(match => new
                {
                    Path = path,
                    Owner = Path.GetRelativePath(ModulesRoot, path)
                        .Split(Path.DirectorySeparatorChar)[0],
                    Schema = match.Groups["schema"].Value
                }))
            .Where(x => moduleSchemas.Contains(x.Schema) &&
                !x.Owner.Equals(x.Schema, StringComparison.OrdinalIgnoreCase))
            .Select(x => $"{Relative(x.Path)} -> {x.Schema}")
            .Distinct(StringComparer.OrdinalIgnoreCase)
            .OrderBy(x => x)
            .ToArray();

        Assert.True(violations.Length == 0,
            "Cross-module SQL access:" + Environment.NewLine +
            string.Join(Environment.NewLine, violations));
    }

    [Fact]
    public void ApiHost_module_layer_debt_can_only_decrease()
    {
        var moduleLayerUsing = new Regex(
            @"using\s+CareSitter\.Modules\.[^.]+\.(?:Domain|Infrastructure)\s*;",
            RegexOptions.CultureInvariant);
        var actual = Directory.EnumerateFiles(ApiHostRoot, "*.cs", SearchOption.AllDirectories)
            .Where(IsSourceFile)
            .Where(path => moduleLayerUsing.IsMatch(File.ReadAllText(path)))
            .Select(path => Path.GetRelativePath(ApiHostRoot, path)
                .Replace(Path.DirectorySeparatorChar, '/'));

        AssertNoNewDebt(actual, ExistingApiHostModuleLayerDebt,
            "ApiHost -> module Domain/Infrastructure");
    }

    private static IEnumerable<string> SourceFiles(string layer) =>
        Directory.EnumerateFiles(ModulesRoot, "*.cs", SearchOption.AllDirectories)
            .Where(path => path.Split(Path.DirectorySeparatorChar)
                .Contains(layer, StringComparer.OrdinalIgnoreCase));

    private static IEnumerable<string> FilesUnderLayer(string layer) => SourceFiles(layer)
        .Where(path => !path.Contains($"{Path.DirectorySeparatorChar}bin{Path.DirectorySeparatorChar}", StringComparison.OrdinalIgnoreCase))
        .Where(path => !path.Contains($"{Path.DirectorySeparatorChar}obj{Path.DirectorySeparatorChar}", StringComparison.OrdinalIgnoreCase));

    private static bool IsSourceFile(string path) =>
        !path.Contains($"{Path.DirectorySeparatorChar}bin{Path.DirectorySeparatorChar}",
            StringComparison.OrdinalIgnoreCase) &&
        !path.Contains($"{Path.DirectorySeparatorChar}obj{Path.DirectorySeparatorChar}",
            StringComparison.OrdinalIgnoreCase);

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
