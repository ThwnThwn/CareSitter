using CareSitter.Modules.Booking.Infrastructure;
using CareSitter.Modules.Catalog.Infrastructure;
using CareSitter.Modules.Identity.Infrastructure;
using CareSitter.Modules.Payments.Infrastructure;
using CareSitter.Modules.People.Infrastructure;
using CareSitter.Modules.Promotion.Infrastructure;
using CareSitter.Modules.Support.Infrastructure;
using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Migrations;

namespace CareSitter.IntegrationTests;

public sealed class SqlMigrationPolicyTests
{
    [Theory]
    [InlineData(typeof(IdentityDbContext))]
    [InlineData(typeof(CatalogDbContext))]
    [InlineData(typeof(PeopleDbContext))]
    [InlineData(typeof(BookingDbContext))]
    [InlineData(typeof(PaymentsDbContext))]
    [InlineData(typeof(SupportDbContext))]
    [InlineData(typeof(PromotionDbContext))]
    public void Module_assembly_does_not_compile_ef_migration_or_snapshot(Type contextType)
    {
        // Assembly inspection only: no connection, Migrate or database mutation.
        Assert.DoesNotContain(contextType.Assembly.GetTypes(),
            type => typeof(Migration).IsAssignableFrom(type) || typeof(ModelSnapshot).IsAssignableFrom(type));
    }
}
