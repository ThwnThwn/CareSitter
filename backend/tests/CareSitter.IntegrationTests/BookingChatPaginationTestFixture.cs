using Xunit;

namespace CareSitter.IntegrationTests;

public sealed class PostgresRaceTestDatabaseFixture : IAsyncLifetime
{
    internal PostgresRaceTestDatabase? Database { get; private set; }

    public async Task InitializeAsync()
    {
        if (!string.IsNullOrWhiteSpace(Environment.GetEnvironmentVariable(PostgresFactAttribute.ConnectionVariable)))
        {
            Database = await PostgresRaceTestDatabase.CreateAsync();
        }
    }

    public async Task DisposeAsync()
    {
        if (Database is not null)
            await Database.DisposeAsync();
    }
}
