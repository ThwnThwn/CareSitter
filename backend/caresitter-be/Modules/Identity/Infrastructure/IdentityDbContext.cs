using CareSitter.Infrastructure.Persistence;
using CareSitter.Infrastructure.Security;
using Microsoft.EntityFrameworkCore;

namespace CareSitter.Modules.Identity.Infrastructure;

/// <summary>DbContext module Identity — schema "identity" (users, user_devices, audit_logs).</summary>
public sealed class IdentityDbContext : ModuleDbContext
{
    public const string SchemaName = "identity";

    public IdentityDbContext(DbContextOptions<IdentityDbContext> options, ICurrentUser? currentUser = null)
        : base(options, currentUser) { }

    protected override string Schema => SchemaName;
}
