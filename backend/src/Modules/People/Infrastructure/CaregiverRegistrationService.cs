using CareSitter.Contracts.Services;
using CareSitter.Modules.People.Domain;
using Microsoft.EntityFrameworkCore;

namespace CareSitter.Modules.People.Infrastructure;

internal sealed class CaregiverRegistrationService(PeopleDbContext db)
    : ICaregiverRegistrationService
{
    public async Task EnsureProfileAsync(
        Guid userId, string? fullName, CancellationToken ct = default)
    {
        if (await db.CaregiverProfiles.AnyAsync(x => x.UserId == userId, ct)) return;
        var created = CaregiverProfile.Create(userId);
        if (created.IsFailure) return;
        created.Value.UpdateProfile(fullName: fullName?.Trim());
        db.CaregiverProfiles.Add(created.Value);
        await db.SaveChangesAsync(ct);
    }
}
