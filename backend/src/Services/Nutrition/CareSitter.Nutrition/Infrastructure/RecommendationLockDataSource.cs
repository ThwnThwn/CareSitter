using Npgsql;

namespace CareSitter.Nutrition.Infrastructure;

internal sealed class RecommendationLockDataSource : IAsyncDisposable
{
    private readonly NpgsqlDataSource _source;
    public RecommendationLockDataSource(string connectionString)
    {
        var settings = new NpgsqlConnectionStringBuilder(connectionString);
        settings.ApplicationName += "/recommendation-lock";
        settings.MaxPoolSize = 8;
        settings.MinPoolSize = 0;
        // Defense in depth; NutritionStore also discards the physical session if unlock fails.
        settings.NoResetOnClose = false;
        _source = NpgsqlDataSource.Create(settings.ConnectionString);
    }
    public ValueTask<NpgsqlConnection> OpenConnectionAsync(CancellationToken ct) => _source.OpenConnectionAsync(ct);
    public ValueTask DisposeAsync() => _source.DisposeAsync();
}
