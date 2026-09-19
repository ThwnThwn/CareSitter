using System.Text.RegularExpressions;
using Npgsql;

namespace CareSitter.IntegrationTests;

[AttributeUsage(AttributeTargets.Method)]
internal sealed class PostgresFactAttribute : FactAttribute
{
    public const string ConnectionVariable = "CARESITTER_TEST_ADMIN_CONNECTION";

    public PostgresFactAttribute()
    {
        if (string.IsNullOrWhiteSpace(Environment.GetEnvironmentVariable(ConnectionVariable)))
            Skip = $"Set {ConnectionVariable} to run PostgreSQL race tests.";
    }
}

internal sealed class PostgresRaceTestDatabase : IAsyncDisposable
{
    private static readonly Regex SafeDatabaseName = new(
        "^caresitter_race_[a-f0-9]{32}$", RegexOptions.CultureInvariant);

    private readonly string _adminConnectionString;
    private readonly string _databaseName;

    private PostgresRaceTestDatabase(
        string adminConnectionString,
        string databaseName,
        string connectionString)
    {
        _adminConnectionString = adminConnectionString;
        _databaseName = databaseName;
        ConnectionString = connectionString;
    }

    public string ConnectionString { get; }

    public static async Task<PostgresRaceTestDatabase> CreateAsync()
    {
        var configured = Environment.GetEnvironmentVariable(PostgresFactAttribute.ConnectionVariable)
            ?? throw new InvalidOperationException("PostgreSQL test connection is not configured.");
        var adminBuilder = new NpgsqlConnectionStringBuilder(configured)
        {
            Database = "postgres",
            Pooling = false,
            IncludeErrorDetail = true
        };
        var databaseName = $"caresitter_race_{Guid.NewGuid():N}";
        if (!SafeDatabaseName.IsMatch(databaseName))
            throw new InvalidOperationException("Generated an unsafe test database name.");

        await using (var admin = new NpgsqlConnection(adminBuilder.ConnectionString))
        {
            await admin.OpenAsync();
            await using var create = new NpgsqlCommand($"CREATE DATABASE \"{databaseName}\"", admin);
            await create.ExecuteNonQueryAsync();
        }

        var testBuilder = new NpgsqlConnectionStringBuilder(configured)
        {
            Database = databaseName,
            IncludeErrorDetail = true
        };
        var database = new PostgresRaceTestDatabase(
            adminBuilder.ConnectionString, databaseName, testBuilder.ConnectionString);
        try
        {
            await database.ApplySchemaAsync();
            return database;
        }
        catch
        {
            await database.DisposeAsync();
            throw;
        }
    }

    public async Task<NpgsqlConnection> OpenConnectionAsync()
    {
        var connection = new NpgsqlConnection(ConnectionString);
        await connection.OpenAsync();
        return connection;
    }

    private async Task ApplySchemaAsync()
    {
        var migrationDirectory = FindMigrationDirectory();
        var files = Directory.GetFiles(migrationDirectory, "*.sql")
            .OrderBy(Path.GetFileName, StringComparer.Ordinal)
            .ToArray();

        await using var connection = await OpenConnectionAsync();
        foreach (var file in files)
        {
            try
            {
                var sql = await File.ReadAllTextAsync(file);
                await using var command = new NpgsqlCommand(sql, connection) { CommandTimeout = 120 };
                await command.ExecuteNonQueryAsync();
            }
            catch (Exception exception)
            {
                throw new InvalidOperationException(
                    $"Failed to apply test schema file '{Path.GetFileName(file)}'.", exception);
            }
        }
    }

    private static string FindMigrationDirectory()
    {
        for (var directory = new DirectoryInfo(AppContext.BaseDirectory);
             directory is not null;
             directory = directory.Parent)
        {
            var candidate = Path.Combine(directory.FullName, "init-db");
            if (Directory.Exists(candidate)) return candidate;
        }

        throw new DirectoryNotFoundException("Could not locate backend/init-db for PostgreSQL tests.");
    }

    public async ValueTask DisposeAsync()
    {
        if (!SafeDatabaseName.IsMatch(_databaseName))
            throw new InvalidOperationException("Refusing to drop an unexpected database name.");

        NpgsqlConnection.ClearAllPools();
        await using var admin = new NpgsqlConnection(_adminConnectionString);
        await admin.OpenAsync();
        await using (var terminate = new NpgsqlCommand(
            "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = @database AND pid <> pg_backend_pid()",
            admin))
        {
            terminate.Parameters.AddWithValue("database", _databaseName);
            await terminate.ExecuteNonQueryAsync();
        }
        await using var drop = new NpgsqlCommand($"DROP DATABASE IF EXISTS \"{_databaseName}\"", admin);
        await drop.ExecuteNonQueryAsync();
    }
}
