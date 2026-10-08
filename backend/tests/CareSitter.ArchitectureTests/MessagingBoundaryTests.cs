using System.Xml.Linq;

namespace CareSitter.ArchitectureTests;

/// <summary>Enforces messaging package boundaries without granting exceptions to application code.</summary>
public sealed class MessagingBoundaryTests
{
    private static string Root()
    {
        var directory = new DirectoryInfo(AppContext.BaseDirectory);
        while (directory is not null && !File.Exists(Path.Combine(directory.FullName, "backend", "CareSitter.sln"))) directory = directory.Parent;
        return directory?.FullName ?? throw new DirectoryNotFoundException("Repository root not found.");
    }

    [Theory]
    [InlineData("Contracts", "")]
    [InlineData("Abstractions", "Contracts")]
    [InlineData("Kafka", "Abstractions,Contracts")]
    [InlineData("Persistence", "Abstractions,Contracts")]
    public void Messaging_project_references_follow_the_declared_dependency_direction(string project, string allowed)
    {
        var path = Path.Combine(Root(), "backend", "caresitter-be", "Shared", $"CareSitter.Messaging.{project}");
        var xml = XDocument.Load(Path.Combine(path, $"CareSitter.Messaging.{project}.csproj"));
        var targets = xml.Descendants("ProjectReference").Select(x => Path.GetFileNameWithoutExtension(
            ((string)x.Attribute("Include")!).Replace('\\', '/'))).ToArray();
        var names = allowed.Split(',', StringSplitOptions.RemoveEmptyEntries).Select(x => "CareSitter.Messaging." + x).ToArray();
        Assert.Equal(names.Order(), targets.Order());
        if (project == "Kafka") Assert.DoesNotContain(xml.Descendants("PackageReference"),
            x => ((string?)x.Attribute("Include"))?.Contains("EntityFrameworkCore") == true);
        if (project == "Contracts") Assert.Empty(xml.Descendants("PackageReference"));
    }

    [Fact]
    public void Module_application_and_domain_layers_do_not_depend_on_transport_or_persistence()
    {
        var modules = Path.Combine(Root(), "backend", "caresitter-be", "Modules");
        foreach (var file in Directory.EnumerateFiles(modules, "*.cs", SearchOption.AllDirectories)
            .Where(x => x.Replace('\\', '/').Contains("/Application/") || x.Replace('\\', '/').Contains("/Domain/")))
        {
            var text = File.ReadAllText(file);
            Assert.DoesNotContain("using CareSitter.Messaging.Kafka", text);
            Assert.DoesNotContain("using CareSitter.Messaging.Persistence", text);
            Assert.DoesNotContain("using Confluent.Kafka", text);
        }
        foreach (var project in Directory.EnumerateFiles(modules, "*.csproj", SearchOption.AllDirectories))
            Assert.DoesNotContain(XDocument.Load(project).Descendants("ProjectReference"), x =>
                ((string?)x.Attribute("Include"))?.Contains("CareSitter.Messaging.Kafka") == true);
    }
}
