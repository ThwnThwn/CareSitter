using Npgsql;

namespace CareSitter.AppHost;

internal static class NutritionDatabaseConfiguration
{
    public static async Task ConfigureSharedServerRuntimeRoleAsync(string careSitterConnection,
        string database, string username, string password)
    {
        var runtimeConnection = BuildSharedServerConnection(
            careSitterConnection, database, username, password);
        var adminConnection = new NpgsqlConnectionStringBuilder(careSitterConnection)
        {
            Database = database
        };

        await using var connection = new NpgsqlConnection(adminConnection.ConnectionString);
        await connection.OpenAsync();
        var quoting = new NpgsqlCommandBuilder();
        var quotedPassword = password.Replace("'", "''", StringComparison.Ordinal);
        var sql = $"ALTER ROLE {quoting.QuoteIdentifier(username)} PASSWORD '{quotedPassword}'";
        await using var command = new NpgsqlCommand(sql, connection);
        await command.ExecuteNonQueryAsync();

        // Validate the exact least-privilege connection that Nutrition will receive.
        await using var validation = new NpgsqlConnection(runtimeConnection);
        await validation.OpenAsync();
    }

    public static string BuildSharedServerConnection(string careSitterConnection, string database,
        string username, string password)
    {
        if (string.IsNullOrWhiteSpace(careSitterConnection))
            throw new InvalidOperationException("ConnectionStrings:CareSitter is required.");
        if (string.IsNullOrWhiteSpace(database) || string.IsNullOrWhiteSpace(username))
            throw new InvalidOperationException("Nutrition database name and username are required.");
        if (password.Length is < 32 or > 256)
            throw new InvalidOperationException("Nutrition database password must contain 32..256 characters.");

        var connection = new NpgsqlConnectionStringBuilder(careSitterConnection)
        {
            Database = database,
            Username = username,
            Password = password
        };
        return connection.ConnectionString;
    }
}
