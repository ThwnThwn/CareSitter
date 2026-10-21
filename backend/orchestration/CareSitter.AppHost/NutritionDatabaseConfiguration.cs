using Npgsql;

namespace CareSitter.AppHost;

internal static class NutritionDatabaseConfiguration
{
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
