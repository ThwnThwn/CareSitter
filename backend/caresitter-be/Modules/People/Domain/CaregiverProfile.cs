using CareSitter.SharedKernel.Domain;
using CareSitter.SharedKernel.Results;
using NetTopologySuite.Geometries;

namespace CareSitter.Modules.People.Domain;

/// <summary>
/// Aggregate root cho ho so nguoi chăm sóc (caregiver). Map sang bang people.caregiver_profiles.
/// user_id unique (1-1 voi identity.users). CCCD luu dang encrypted + hash. Vi tri phuc vu
/// dung geography(Point,4326) cho truy van khong gian.
/// </summary>
public sealed class CaregiverProfile : AggregateRoot
{
    private CaregiverProfile() { } // EF

    private CaregiverProfile(Guid id, Guid userId) : base(id)
    {
        UserId = userId;
        CertificateUrls = "[]";
    }

    public Guid UserId { get; private set; }
    public string? FullName { get; private set; }
    public DateOnly? DateOfBirth { get; private set; }

    /// <summary>Allowed values: MALE, FEMALE, OTHER, UNSPECIFIED.</summary>
    public string? Gender { get; private set; }
    public string? CccdNumberEncrypted { get; private set; }
    public string? CccdHash { get; private set; }
    public string? CccdFrontUrl { get; private set; }
    public string? CccdBackUrl { get; private set; }
    public string? CertificateUrls { get; private set; } = "[]";
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

    public Result SubmitKyc(
        string cccdEncrypted,
        string cccdHash,
        string cccdFrontUrl,
        string cccdBackUrl,
        string? certificateUrls = null)
    {
        if (KycStatus is not ("DRAFT" or "REJECTED"))
            return Error.Conflict("caregiver.kyc_status", $"không thể nop KYC khi trạng thái la {KycStatus}.");
        if (string.IsNullOrWhiteSpace(cccdEncrypted))
            return Error.Validation("caregiver.cccd", "cccd_number_encrypted la bat buoc.");
        if (string.IsNullOrWhiteSpace(cccdHash))
            return Error.Validation("caregiver.cccd_hash", "cccd_hash la bat buoc.");
        if (string.IsNullOrWhiteSpace(cccdFrontUrl))
            return Error.Validation("caregiver.cccd_front", "Anh mat truoc CCCD la bat buoc.");
        if (string.IsNullOrWhiteSpace(cccdBackUrl))
            return Error.Validation("caregiver.cccd_back", "Anh mat sau CCCD la bat buoc.");

        CccdNumberEncrypted = cccdEncrypted;
        CccdHash = cccdHash;
        CccdFrontUrl = cccdFrontUrl;
        CccdBackUrl = cccdBackUrl;
        CertificateUrls = string.IsNullOrWhiteSpace(certificateUrls) ? "[]" : certificateUrls;
        KycStatus = "PENDING";
        return Result.Success();
    }

    public Result ApproveKyc()
    {
        if (KycStatus != "PENDING")
            return Error.Conflict("caregiver.kyc_status", $"không thể duyet KYC khi trạng thái la {KycStatus}.");
        KycStatus = "APPROVED";
        return Result.Success();
    }

    public Result RejectKyc()
    {
        if (KycStatus != "PENDING")
            return Error.Conflict("caregiver.kyc_status", $"không thể tu choi KYC khi trạng thái la {KycStatus}.");
        KycStatus = "REJECTED";
        return Result.Success();
    }

    public Result UpdateProfile(
        string? fullName = null, string? bio = null, int? yearsOfExperience = null,
        long? hourlyRateExpected = null, string? skills = null,
        string? serviceCity = null, string? serviceDistrict = null,
        string? gender = null, DateOnly? dateOfBirth = null)
    {
        if (fullName is not null) FullName = fullName;
        if (bio is not null) Bio = bio;
        if (yearsOfExperience.HasValue) YearsOfExperience = yearsOfExperience.Value;
        if (hourlyRateExpected.HasValue) HourlyRateExpected = hourlyRateExpected.Value;
        if (skills is not null) Skills = skills;
        if (serviceCity is not null) ServiceCity = serviceCity;
        if (serviceDistrict is not null) ServiceDistrict = serviceDistrict;
        if (gender is not null) Gender = gender;
        if (dateOfBirth.HasValue) DateOfBirth = dateOfBirth.Value;
        return Result.Success();
    }

    public Result SetAvailabilityStatus(string status)
    {
        var normalized = status?.Trim().ToUpperInvariant();
        if (normalized is not ("ONLINE" or "OFFLINE" or "BUSY"))
            return Error.Validation("caregiver.availability_status", "trạng thái phai la ONLINE, OFFLINE hoac BUSY.");
        AvailabilityStatus = normalized;
        return Result.Success();
    }
}
