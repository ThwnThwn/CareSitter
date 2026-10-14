using System.Xml.Linq;

namespace CareSitter.Nutrition.Tests;

public sealed class ServiceArchitectureTests
{
    [Fact]
    public void Runtime_has_no_project_dependency_on_monolith_and_owns_its_schema()
    {
        var root = FindRoot();
        var project = XDocument.Load(Path.Combine(root, "src/CareSitter.Nutrition/CareSitter.Nutrition.csproj"));
        Assert.Empty(project.Descendants("ProjectReference"));
        var source = Directory.EnumerateFiles(Path.Combine(root, "src/CareSitter.Nutrition"), "*.cs", SearchOption.AllDirectories)
            .Where(p => !p.Contains(Path.DirectorySeparatorChar + "obj" + Path.DirectorySeparatorChar));
        foreach (var file in source)
        {
            var text = File.ReadAllText(file);
            Assert.DoesNotContain("CareSitter.Modules.", text);
            Assert.DoesNotContain("people.beneficiaries", text);
        }
    }

    [Theory]
    [InlineData("Domain")]
    [InlineData("Application")]
    public void Inner_layers_do_not_depend_on_database_transport_or_infrastructure(string layer)
    {
        var directory = Path.Combine(FindRoot(), "src/CareSitter.Nutrition", layer);
        var forbidden = new[] { "CareSitter.Nutrition.Infrastructure", "CareSitter.Nutrition.Controllers",
            "Npgsql", "Microsoft.EntityFrameworkCore", "Microsoft.AspNetCore", "Grpc.Core", "HttpClient" };
        foreach (var file in Directory.EnumerateFiles(directory, "*.cs", SearchOption.AllDirectories))
        {
            var text = File.ReadAllText(file);
            foreach (var dependency in forbidden)
                Assert.True(!text.Contains(dependency, StringComparison.Ordinal), $"{file} depends on {dependency}.");
            if (layer == "Domain")
            {
                Assert.DoesNotContain("CareSitter.Nutrition.Application", text);
                Assert.DoesNotContain("MediatR", text);
            }
        }
    }
    internal static string FindRoot()
    {
        for (var dir = new DirectoryInfo(AppContext.BaseDirectory); dir is not null; dir = dir.Parent)
            if (File.Exists(Path.Combine(dir.FullName, "CareSitter.Nutrition.sln"))) return dir.FullName;
        throw new DirectoryNotFoundException();
    }
}
