using CareSitter.Modules.People;
using CareSitter.Modules.People.Infrastructure;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;

namespace CareSitter.IntegrationTests;

public sealed class TestEntityFrameworkServicesTests
{
    [Fact]
    public void Many_isolated_data_sources_can_build_models_and_scopes_reuse_fixture_services()
    {
        for (var index = 0; index < 30; index++)
        {
            using var fixture = Fixture("fixture_" + index);
            using var firstScope = fixture.CreateScope();
            using var secondScope = fixture.CreateScope();
            var first = firstScope.ServiceProvider.GetRequiredService<PeopleDbContext>();
            var second = secondScope.ServiceProvider.GetRequiredService<PeopleDbContext>();
            Assert.NotSame(first, second);
            Assert.Same(first.Model, second.Model);
        }
    }

    [Fact]
    public void Different_fixtures_keep_their_models_and_database_connections_separate()
    {
        using var firstFixture = Fixture("first_fixture");
        using var secondFixture = Fixture("second_fixture");
        using var firstScope = firstFixture.CreateScope();
        using var secondScope = secondFixture.CreateScope();
        var first = firstScope.ServiceProvider.GetRequiredService<PeopleDbContext>();
        var second = secondScope.ServiceProvider.GetRequiredService<PeopleDbContext>();
        Assert.NotSame(first.Model, second.Model);
        Assert.Equal("first_fixture", first.Database.GetDbConnection().Database);
        Assert.Equal("second_fixture", second.Database.GetDbConnection().Database);
    }

    private static ServiceProvider Fixture(string database)
    {
        // Model initialization resolves EF/Npgsql services without opening a database connection.
        var connection = $"Host=127.0.0.1;Port=1;Database={database};Username=fixture";
        var services = new ServiceCollection();
        services.AddLogging();
        new PeopleModule().RegisterServices(services, new ConfigurationBuilder()
            .AddInMemoryCollection(new Dictionary<string, string?> { ["ConnectionStrings:CareSitter"] = connection }).Build());
        services.UseFixtureProvider<PeopleDbContext>();
        return services.BuildServiceProvider();
    }
}
