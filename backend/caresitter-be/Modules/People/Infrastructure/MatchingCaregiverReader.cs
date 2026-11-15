using CareSitter.Contracts.Services;
using CareSitter.Contracts.Services.Routing;
using Microsoft.EntityFrameworkCore;

namespace CareSitter.Modules.People.Infrastructure;

internal sealed class MatchingCaregiverReader(PeopleDbContext db) : IMatchingCaregiverReader
{
    public async Task<IReadOnlyList<MatchingCaregiverProfile>> ListAvailableAsync(
        CancellationToken ct = default) => await ListAsync(false, ct);

    public Task<IReadOnlyList<MatchingCaregiverProfile>> ListForScheduledBookingAsync(
        CancellationToken ct = default) => ListAsync(true, ct);

    private async Task<IReadOnlyList<MatchingCaregiverProfile>> ListAsync(
        bool scheduled, CancellationToken ct)
    {
        var profiles = await db.CaregiverProfiles.AsNoTracking()
            .Where(x => x.DeletedAt == null && x.KycStatus == "APPROVED" &&
                (x.AvailabilityStatus == "ONLINE" ||
                    (scheduled && (x.AvailabilityStatus == "OFFLINE" || x.AvailabilityStatus == "BUSY"))))
            .ToListAsync(ct);
        return profiles.Select(x => new MatchingCaregiverProfile(
            x.Id, x.KycStatus, x.AvailabilityStatus, x.Skills,
            x.ServiceCity, x.ServiceDistrict,
            x.ServiceCenterLocation is null
                ? null
                : new GeoPoint(x.ServiceCenterLocation.Y, x.ServiceCenterLocation.X),
            x.ServiceRadiusMeters, x.RatingAvg, x.RatingCount,
            x.YearsOfExperience, x.DeletedAt)).ToArray();
    }
}
