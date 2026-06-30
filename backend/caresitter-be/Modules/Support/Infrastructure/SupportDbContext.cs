using CareSitter.Infrastructure.Persistence;
using CareSitter.Infrastructure.Security;
using Microsoft.EntityFrameworkCore;

namespace CareSitter.Modules.Support.Infrastructure;

/// <summary>DbContext module Support — schema "support" (disputes, support_tickets, reviews, notifications).</summary>
public sealed class SupportDbContext : ModuleDbContext
{
    public const string SchemaName = "support";

    public SupportDbContext(DbContextOptions<SupportDbContext> options, ICurrentUser? currentUser = null)
        : base(options, currentUser) { }

    protected override string Schema => SchemaName;
}
