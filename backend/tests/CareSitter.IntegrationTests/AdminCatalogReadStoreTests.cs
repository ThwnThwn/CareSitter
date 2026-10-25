using CareSitter.Modules.Catalog.Application;
using CareSitter.Modules.Catalog.Domain;
using CareSitter.Modules.Catalog.Infrastructure;
using Microsoft.EntityFrameworkCore;

namespace CareSitter.IntegrationTests;

[Trait("Category", "PostgreSQL")]
public sealed class AdminCatalogReadStoreTests
{
    [PostgresFact]
    public async Task Admin_service_list_does_not_evaluate_a_span_parameter()
    {
        await using var database = await PostgresRaceTestDatabase.CreateAsync();
        var options = new DbContextOptionsBuilder<CatalogDbContext>()
            .UseNpgsql(database.ConnectionString, npgsql => npgsql.UseNetTopologySuite())
            .Options;
        await using var db = new CatalogDbContext(options);
        var first = ServiceType.Create("CATALOG_TEST_FIRST", "Gói kiểm thử thứ nhất").Value;
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
        Assert.Single(firstResult.PricingRules, rule => rule.Id == price.Id);
        Assert.Contains(services, service => service.Id == second.Id);
    }
}
