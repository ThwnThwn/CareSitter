using CareSitter.Modules.Catalog.Application;
using CareSitter.Modules.Catalog.Domain;
using CareSitter.Modules.Catalog.Infrastructure;
using Microsoft.EntityFrameworkCore;

namespace CareSitter.IntegrationTests;

[Trait("Category", "PostgreSQL")]
public sealed class AdminCatalogReadStoreTests
{
    [PostgresFact]
    public async Task Public_catalog_keeps_hourly_services_when_session_programs_are_added()
    {
        await using var database = await PostgresRaceTestDatabase.CreateAsync();
        var options = new DbContextOptionsBuilder<CatalogDbContext>()
            .UseNpgsql(database.ConnectionString, npgsql => npgsql.UseNetTopologySuite())
            .Options;
        await using var db = new CatalogDbContext(options);
        var storeType = typeof(CatalogDbContext).Assembly.GetType(
            "CareSitter.Modules.Catalog.Infrastructure.CatalogReadStore",
            throwOnError: true)!;
        var store = (ICatalogReadStore)Activator.CreateInstance(storeType, db)!;
        var expectedHourlyPrices = new Dictionary<string, long>
        {
            ["NONMED_COMPANION"] = 80_000,
            ["APPOINTMENT_COMPANION"] = 90_000,
            ["NONMED_DAY"] = 85_000,
            ["NONMED_ESSENTIAL"] = 120_000,
            ["NONMED_NIGHT"] = 120_000,
            ["MOBILITY_SUPPORT"] = 130_000,
            ["NURSING_VITALS"] = 200_000,
            ["CHRONIC_CARE"] = 220_000,
            ["PALLIATIVE_CARE"] = 280_000,
            ["HOME_PHYSIOTHERAPY"] = 250_000,
            ["COGNITIVE_STIMULATION"] = 200_000,
            ["ACUPUNCTURE_ACUPRESSURE"] = 300_000
        };

        var services = await store.ListActiveServicesAsync(DateTimeOffset.UtcNow);

        foreach (var expected in expectedHourlyPrices)
        {
            var service = Assert.Single(services, item => item.Code == expected.Key);
            Assert.Equal(expected.Value, service.BaseHourlyPrice);
            Assert.Empty(service.Plans);
        }
        Assert.Contains(services, item => item.Code == "AN_NHIEN" && item.Plans.Count == 7);
        Assert.Contains(services, item => item.Code == "AN_KHANG" && item.Plans.Count == 7);
        Assert.Contains(services, item => item.Code == "THAN_TRI" && item.Plans.Count == 3);
    }

    [PostgresFact]
    public async Task Active_service_list_does_not_evaluate_a_span_parameter()
    {
        await using var database = await PostgresRaceTestDatabase.CreateAsync();
        var options = new DbContextOptionsBuilder<CatalogDbContext>()
            .UseNpgsql(database.ConnectionString, npgsql => npgsql.UseNetTopologySuite())
            .Options;
        await using var db = new CatalogDbContext(options);
        var now = DateTimeOffset.UtcNow;
        var service = ServiceType.Create("CATALOG_ACTIVE_TEST", "Gói kiểm thử đang hoạt động",
            imageUrl: "https://cdn.example.test/catalog-active.webp").Value;
        var price = PricingRule.Create("Giá kiểm thử", service.Id, 120_000).Value;
        var plan = ServicePlan.Create(
            service.Id,
            "CATALOG_ACTIVE_TEST_SINGLE",
            "Một buổi kiểm thử",
            ServicePlanBillingUnits.Session,
            durationMinutes: 120,
            includedSessions: 1,
            totalPrice: 200_000,
            effectiveFrom: now.AddMinutes(-1)).Value;
        db.ServiceTypes.Add(service);
        await db.SaveChangesAsync();
        db.PricingRules.Add(price);
        db.ServicePlans.Add(plan);
        await db.SaveChangesAsync();
        var storeType = typeof(CatalogDbContext).Assembly.GetType(
            "CareSitter.Modules.Catalog.Infrastructure.CatalogReadStore",
            throwOnError: true)!;
        var store = (ICatalogReadStore)Activator.CreateInstance(storeType, db)!;

        var services = await store.ListActiveServicesAsync(now);

        var result = Assert.Single(services, item => item.Id == service.Id);
        Assert.Equal("https://cdn.example.test/catalog-active.webp", result.ImageUrl);
        Assert.Single(result.Plans, item => item.Id == plan.Id);
    }

    [PostgresFact]
    public async Task Admin_service_list_does_not_evaluate_a_span_parameter()
    {
        await using var database = await PostgresRaceTestDatabase.CreateAsync();
        var options = new DbContextOptionsBuilder<CatalogDbContext>()
            .UseNpgsql(database.ConnectionString, npgsql => npgsql.UseNetTopologySuite())
            .Options;
        await using var db = new CatalogDbContext(options);
        var first = ServiceType.Create("CATALOG_TEST_FIRST", "Gói kiểm thử thứ nhất",
            imageUrl: "https://cdn.example.test/catalog-admin.webp").Value;
        var second = ServiceType.Create("CATALOG_TEST_SECOND", "Gói kiểm thử thứ hai").Value;
        var price = PricingRule.Create("Giá kiểm thử", first.Id, 120_000).Value;
        db.ServiceTypes.AddRange(first, second);
        await db.SaveChangesAsync();
        db.PricingRules.Add(price);
        await db.SaveChangesAsync();
        var storeType = typeof(CatalogDbContext).Assembly.GetType(
            "CareSitter.Modules.Catalog.Infrastructure.CatalogReadStore",
            throwOnError: true)!;
        var store = (ICatalogReadStore)Activator.CreateInstance(storeType, db)!;

        var services = await store.ListAdminServicesAsync();

        var firstResult = Assert.Single(services, service => service.Id == first.Id);
        Assert.Equal("https://cdn.example.test/catalog-admin.webp", firstResult.ImageUrl);
        Assert.Single(firstResult.PricingRules, rule => rule.Id == price.Id);
        Assert.Contains(services, service => service.Id == second.Id);
    }
}
