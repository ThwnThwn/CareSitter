using CareSitter.Infrastructure.Persistence;
using CareSitter.Infrastructure.Security;
using Microsoft.EntityFrameworkCore;

namespace CareSitter.Modules.Catalog.Infrastructure;

/// <summary>DbContext module Catalog — schema "catalog" (service_types, pricing_rules, addresses, media_assets).</summary>
public sealed class CatalogDbContext : ModuleDbContext
{
    public const string SchemaName = "catalog";

    public CatalogDbContext(DbContextOptions<CatalogDbContext> options, ICurrentUser? currentUser = null)
        : base(options, currentUser) { }

    protected override string Schema => SchemaName;
}
