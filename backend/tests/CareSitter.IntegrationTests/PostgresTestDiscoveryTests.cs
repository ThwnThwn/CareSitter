using System.Reflection;

namespace CareSitter.IntegrationTests;

public sealed class PostgresTestDiscoveryTests
{
    [Fact]
    public void EveryPostgresFact_IsIncludedInThePostgresRunnerCategory()
    {
        var postgresTests = typeof(PostgresFactAttribute).Assembly.GetTypes()
            .SelectMany(type => type.GetMethods().Where(method =>
                    method.IsDefined(typeof(PostgresFactAttribute), inherit: true))
                .Select(method => (Type: type, Method: method)))
            .ToArray();

        Assert.NotEmpty(postgresTests);
        foreach (var (type, method) in postgresTests)
        {
            var traits = type.GetCustomAttributesData()
                .Concat(method.GetCustomAttributesData());
            Assert.True(traits.Any(attribute =>
                    attribute.AttributeType == typeof(TraitAttribute) &&
                    attribute.ConstructorArguments.Count == 2 &&
                    Equals(attribute.ConstructorArguments[0].Value, "Category") &&
                    Equals(attribute.ConstructorArguments[1].Value, "PostgreSQL")),
                $"{type.Name}.{method.Name} would be silently omitted by Category=PostgreSQL.");
        }
    }
}
