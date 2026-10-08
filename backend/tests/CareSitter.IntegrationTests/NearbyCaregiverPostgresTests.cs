using CareSitter.Modules.People;
using CareSitter.Modules.People.Application;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Npgsql;

namespace CareSitter.IntegrationTests;

[Trait("Category", "PostgreSQL")]
public sealed class NearbyCaregiverPostgresTests : IAsyncLifetime
{
    private PostgresRaceTestDatabase database = null!;
    public async Task InitializeAsync() => database = await PostgresRaceTestDatabase.CreateAsync();
    public async Task DisposeAsync() { if (database is not null) await database.DisposeAsync(); }
    private ServiceProvider Services()
    {
        var configuration = new ConfigurationBuilder().AddInMemoryCollection(new Dictionary<string, string?>
        { ["ConnectionStrings:CareSitter"] = database.ConnectionString }).Build();
        var services = new ServiceCollection();
        new PeopleModule().RegisterServices(services, configuration);
        services.AddLogging();
        return services.BuildServiceProvider();
    }
    private static CaregiverSearchCriteria Nearby() => new(10, 106, null, null,
        null, null, null, null, null, 1, 20);

    private async Task<Guid> Seed(double? lat, int? radius = null, decimal rating = 4m, string status = "APPROVED")
    {
        var user = Guid.NewGuid(); var profile = Guid.NewGuid();
        await using var connection = await database.OpenConnectionAsync();
        await using var command = new NpgsqlCommand("""
            INSERT INTO identity.users(id,email,roles) VALUES (@user,@email,ARRAY['CAREGIVER']::varchar[]);
            INSERT INTO people.caregiver_profiles(id,user_id,full_name,kyc_status,rating_avg,
                service_center_location,service_radius_meters)
            VALUES (@profile,@user,'Nearby test',@status,@rating,
                CASE WHEN @has_location THEN ST_SetSRID(ST_MakePoint(106.0,@lat),4326)::geography ELSE NULL END,@radius);
            """, connection);
        command.Parameters.AddWithValue("user", user);
        command.Parameters.AddWithValue("profile", profile);
        command.Parameters.AddWithValue("email", $"{user:N}@nearby.test");
        command.Parameters.AddWithValue("status", status);
        command.Parameters.AddWithValue("rating", rating);
        command.Parameters.AddWithValue("has_location", lat.HasValue);
        command.Parameters.AddWithValue("lat", lat ?? 0d);
        command.Parameters.AddWithValue("radius", NpgsqlTypes.NpgsqlDbType.Integer, (object?)radius ?? DBNull.Value);
        await command.ExecuteNonQueryAsync();
        return profile;
    }

    [PostgresFact]
    public async Task Nearby_filters_service_radius_and_missing_locations_orders_distance_and_returns_meters()
    {
        var near = await Seed(10.01, rating: 1m);
        var further = await Seed(10.04, rating: 5m);
        await Seed(10.2);
        await Seed(null);
        await Seed(10.001, status: "PENDING");
        await Seed(10.015, radius: 1000);
        await using var services = Services();
        using var scope = services.CreateScope();
        var result = await scope.ServiceProvider.GetRequiredService<IPeopleReadStore>().SearchCaregiversAsync(Nearby());
        Assert.Equal(2, result.Total);
        Assert.Equal(new[] { near, further }, result.Items.Select(x => x.Id));
        Assert.InRange(result.Items[0].DistanceMeters!.Value, 1050, 1150);
        Assert.InRange(result.Items[1].DistanceMeters!.Value, 4300, 4500);
    }

    [PostgresFact]
    public async Task Configured_service_radius_can_extend_default_and_pagination_keeps_nearest_order()
    {
        var near = await Seed(10.005);
        var extended = await Seed(10.12, radius: 20000);
        await Seed(10.12);
        await using var services = Services();
        using var scope = services.CreateScope();
        var store = scope.ServiceProvider.GetRequiredService<IPeopleReadStore>();
        var first = await store.SearchCaregiversAsync(Nearby() with { PageSize = 1 });
        var second = await store.SearchCaregiversAsync(Nearby() with { Page = 2, PageSize = 1 });
        Assert.Equal(2, first.Total);
        Assert.Equal(near, Assert.Single(first.Items).Id);
        Assert.Equal(extended, Assert.Single(second.Items).Id);
        Assert.InRange(second.Items[0].DistanceMeters!.Value, 13000, 14000);
    }

    [PostgresFact]
    public async Task General_directory_without_coordinates_does_not_claim_distances()
    {
        var withoutLocation = await Seed(null);
        var distant = await Seed(10.2);
        await using var services = Services();
        using var scope = services.CreateScope();
        var result = await scope.ServiceProvider.GetRequiredService<IPeopleReadStore>().SearchCaregiversAsync(
            Nearby() with { Latitude = null, Longitude = null });
        Assert.Contains(result.Items, caregiver => caregiver.Id == withoutLocation);
        Assert.Contains(result.Items, caregiver => caregiver.Id == distant);
        Assert.All(result.Items, caregiver => Assert.Null(caregiver.DistanceMeters));
    }
}
