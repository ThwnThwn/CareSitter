using CareSitter.SharedKernel.Domain;
using CareSitter.SharedKernel.Results;
using NetTopologySuite.Geometries;

namespace CareSitter.Modules.People.Domain;

/// <summary>
/// Aggregate root cho ho so nguoi cham soc (caregiver). Map sang bang people.caregiver_profiles.
/// user_id unique (1-1 voi identity.users). CCCD luu dang encrypted + hash. Vi tri phuc vu
/// dung geography(Point,4326) cho truy van khong gian.
/// </summary>
public sealed class CaregiverProfile : AggregateRoot
{
    private CaregiverProfile() { } // EF

    private CaregiverProfile(Guid id, Guid userId) : base(id)
    {
        UserId = userId;
    }

    public Guid UserId { get; private set; }
    public string? FullName { get; private set; }
    public DateOnly? DateOfBirth { get; private set; }

    /// <summary>Allowed values: MALE, FEMALE, OTHER, UNSPECIFIED.</summary>
    public string? Gender { get; private set; }
    public string? CccdNumberEncrypted { get; private set; }
    public string? CccdHash { get; private set; }
    public string? Bio { get; private set; }
    public int? YearsOfExperience { get; private set; }
    public long? HourlyRateExpected { get; private set; }
    public decimal RatingAvg { get; private set; }
    public int RatingCount { get; private set; }

    /// <summary>Allowed values: DRAFT, PENDING, APPROVED, REJECTED, SUSPENDED.</summary>
    public string KycStatus { get; private set; } = "DRAFT";

    /// <summary>Allowed values: ONLINE, OFFLINE, BUSY.</summary>
    public string AvailabilityStatus { get; private set; } = "OFFLINE";

    /// <summary>jsonb: gom skills + caregiver_skills.</summary>
    public string? Skills { get; private set; }
    public string? ServiceCity { get; private set; }
    public string? ServiceDistrict { get; private set; }

    /// <summary>geography(Point,4326) — tam vung phuc vu (nullable).</summary>
    public Point? ServiceCenterLocation { get; private set; }
    public int? ServiceRadiusMeters { get; private set; }
    public Guid? WalletAccountId { get; private set; }
    public DateTimeOffset? DeletedAt { get; private set; }

    public static Result<CaregiverProfile> Create(Guid userId)
    {
        if (userId == Guid.Empty)
            return Error.Validation("caregiver_profile.user", "user_id la bat buoc.");

        return new CaregiverProfile(Guid.NewGuid(), userId);
    }
}
