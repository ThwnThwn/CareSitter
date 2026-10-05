using System.Text.Json;
using CareSitter.Contracts.Services;
using Microsoft.EntityFrameworkCore;

namespace CareSitter.Modules.People.Infrastructure;

internal sealed class KycDocumentAccess(PeopleDbContext db) : IKycDocumentAccess
{
    public async Task<bool> IsSubmittedAsync(Guid mediaId, Guid ownerUserId, CancellationToken ct)
    {
        var profile = await db.CaregiverProfiles.AsNoTracking().SingleOrDefaultAsync(x =>
            x.UserId == ownerUserId && x.DeletedAt == null, ct);
        if (profile is null) return false;
        if (profile.CccdFrontMediaId == mediaId || profile.CccdBackMediaId == mediaId) return true;
        try { return (JsonSerializer.Deserialize<Guid[]>(profile.CertificateMediaIds) ?? []).Contains(mediaId); }
        catch (JsonException) { return false; }
    }
}
