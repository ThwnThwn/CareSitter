using CareSitter.Modules.People.Application;
using Microsoft.EntityFrameworkCore;
using NetTopologySuite.Geometries;

namespace CareSitter.Modules.People.Infrastructure;

internal sealed class PeopleReadStore(PeopleDbContext db) : IPeopleReadStore
{
    private const int DefaultRadiusMeters = 10_000;

    public async Task<IReadOnlyList<BeneficiaryResponse>> ListBeneficiariesAsync(
        Guid customerId, CancellationToken ct = default)
    {
        await using var transaction = await BeginUserScopeAsync(customerId, ct);
        var entities = await db.Beneficiaries.AsNoTracking()
            .Where(x => x.CustomerId == customerId && x.DeletedAt == null)
            .OrderBy(x => x.FullName)
            .ToListAsync(ct);
        return entities.Select(PeopleResponseMapper.ToResponse).ToArray();
    }

    public async Task<BeneficiaryResponse?> GetBeneficiaryAsync(
        Guid beneficiaryId, Guid customerId, CancellationToken ct = default)
    {
        await using var transaction = await BeginUserScopeAsync(customerId, ct);
        var entity = await db.Beneficiaries.AsNoTracking().SingleOrDefaultAsync(x =>
            x.Id == beneficiaryId && x.CustomerId == customerId && x.DeletedAt == null, ct);
        return entity is null ? null : PeopleResponseMapper.ToResponse(entity);
    }

    public async Task<IReadOnlyList<FamilyContactResponse>> ListFamilyContactsAsync(
        Guid customerId, CancellationToken ct = default)
    {
        await using var transaction = await BeginUserScopeAsync(customerId, ct);
        var contacts = await db.FamilyContacts.AsNoTracking()
            .Where(x => x.CustomerId == customerId && x.DeletedAt == null)
            .OrderBy(x => x.FullName)
            .ToListAsync(ct);
        return contacts.Select(PeopleResponseMapper.ToResponse).ToArray();
    }

    public async Task<CaregiverProfileResponse?> GetCaregiverProfileAsync(
        Guid userId, string? avatarUrl, CancellationToken ct = default)
    {
        var profile = await db.CaregiverProfiles.AsNoTracking()
            .SingleOrDefaultAsync(x => x.UserId == userId && x.DeletedAt == null, ct);
        return profile is null ? null : PeopleResponseMapper.ToProfileResponse(profile, avatarUrl);
    }

    public async Task<PeoplePage<CaregiverKycResponse>> ListCaregiverKycAsync(
        string? status, int page, int pageSize, CancellationToken ct = default)
    {
        var query = db.CaregiverProfiles.AsNoTracking().Where(x => x.DeletedAt == null);
        if (!string.IsNullOrWhiteSpace(status) &&
            !string.Equals(status, "ALL", StringComparison.OrdinalIgnoreCase))
        {
            var normalizedStatus = status.Trim().ToUpperInvariant();
            query = query.Where(x => x.KycStatus == normalizedStatus);
        }

        var total = await query.CountAsync(ct);
        var profiles = await query.OrderByDescending(x => x.UpdatedAt)
            .Skip((page - 1) * pageSize)
            .Take(pageSize)
            .ToListAsync(ct);
        return new PeoplePage<CaregiverKycResponse>(
            profiles.Select(PeopleResponseMapper.ToKycResponse).ToArray(), total, page, pageSize);
    }

    public async Task<CaregiverKycResponse?> GetCaregiverKycAsync(
        Guid caregiverId, CancellationToken ct = default)
    {
        var profile = await db.CaregiverProfiles.AsNoTracking()
            .SingleOrDefaultAsync(x => x.Id == caregiverId && x.DeletedAt == null, ct);
        return profile is null ? null : PeopleResponseMapper.ToKycResponse(profile);
    }

    public async Task<PeoplePage<CaregiverResponse>> SearchCaregiversAsync(
        CaregiverSearchCriteria criteria, CancellationToken ct = default)
    {
        var query = string.IsNullOrWhiteSpace(criteria.Skill)
            ? db.CaregiverProfiles.AsQueryable()
            : db.CaregiverProfiles.FromSqlInterpolated(
                $"SELECT * FROM people.caregiver_profiles WHERE skills::text ILIKE {"%" + criteria.Skill + "%"}");

        query = query.AsNoTracking()
            .Where(x => x.DeletedAt == null && x.KycStatus == "APPROVED");

        if (!string.IsNullOrWhiteSpace(criteria.AvailabilityStatus))
        {
            var availability = criteria.AvailabilityStatus.ToUpperInvariant();
            query = query.Where(x => x.AvailabilityStatus == availability);
        }
        if (criteria.MinimumRating.HasValue)
            query = query.Where(x => x.RatingAvg >= criteria.MinimumRating.Value);

        var useSpatial = criteria.Latitude.HasValue && criteria.Longitude.HasValue &&
                         criteria.Latitude.Value is >= -90 and <= 90 &&
                         criteria.Longitude.Value is >= -180 and <= 180;

        if (useSpatial)
        {
            var customerPoint = new Point(criteria.Longitude!.Value, criteria.Latitude!.Value)
                { SRID = 4326 };
            query = query.Where(x =>
                x.ServiceCenterLocation != null &&
                x.ServiceCenterLocation.IsWithinDistance(customerPoint,
                    x.ServiceRadiusMeters ?? DefaultRadiusMeters));

            var total = await query.CountAsync(ct);
            var entities = await query
                .OrderBy(x => x.ServiceCenterLocation!.Distance(customerPoint))
                .ThenByDescending(x => x.RatingAvg)
                .ThenByDescending(x => x.RatingCount)
                .Skip((criteria.Page - 1) * criteria.PageSize)
                .Take(criteria.PageSize)
                .ToListAsync(ct);
            return new PeoplePage<CaregiverResponse>(entities.Select(x =>
                PeopleResponseMapper.ToCaregiverResponse(x,
                    (int?)x.ServiceCenterLocation?.Distance(customerPoint))).ToArray(),
                total, criteria.Page, criteria.PageSize);
        }

        if (!string.IsNullOrWhiteSpace(criteria.City))
            query = query.Where(x => x.ServiceCity == criteria.City);
        if (!string.IsNullOrWhiteSpace(criteria.District))
            query = query.Where(x => x.ServiceDistrict == criteria.District);

        var fallbackTotal = await query.CountAsync(ct);
        var fallbackEntities = await query
            .OrderByDescending(x => x.RatingAvg)
            .ThenByDescending(x => x.RatingCount)
            .Skip((criteria.Page - 1) * criteria.PageSize)
            .Take(criteria.PageSize)
            .ToListAsync(ct);
        return new PeoplePage<CaregiverResponse>(
            fallbackEntities.Select(x => PeopleResponseMapper.ToCaregiverResponse(x)).ToArray(),
            fallbackTotal, criteria.Page, criteria.PageSize);
    }

    public async Task<CaregiverResponse?> GetApprovedCaregiverAsync(
        Guid caregiverId, CancellationToken ct = default)
    {
        var entity = await db.CaregiverProfiles.AsNoTracking().SingleOrDefaultAsync(x =>
            x.Id == caregiverId && x.DeletedAt == null && x.KycStatus == "APPROVED", ct);
        return entity is null ? null : PeopleResponseMapper.ToCaregiverResponse(entity);
    }

    private async Task<Microsoft.EntityFrameworkCore.Storage.IDbContextTransaction> BeginUserScopeAsync(
        Guid userId, CancellationToken ct)
    {
        var transaction = await db.Database.BeginTransactionAsync(ct);
        await db.Database.ExecuteSqlInterpolatedAsync(
            $"SELECT set_config('app.current_user_id', {userId.ToString()}, true)", ct);
        return transaction;
    }
}
