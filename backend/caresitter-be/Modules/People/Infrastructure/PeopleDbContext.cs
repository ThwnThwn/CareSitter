using CareSitter.Infrastructure.Persistence;
using CareSitter.Infrastructure.Security;
using Microsoft.EntityFrameworkCore;

namespace CareSitter.Modules.People.Infrastructure;

/// <summary>DbContext module People — schema "people" (beneficiaries, caregiver_profiles, availability).</summary>
public sealed class PeopleDbContext : ModuleDbContext
{
    public const string SchemaName = "people";

    public PeopleDbContext(DbContextOptions<PeopleDbContext> options, ICurrentUser? currentUser = null)
        : base(options, currentUser) { }

    protected override string Schema => SchemaName;
}
