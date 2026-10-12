using CareSitter.SharedKernel.Domain;
using CareSitter.SharedKernel.Results;

namespace CareSitter.Modules.People.Domain;

/// <summary>
/// Aggregate root cho người được chăm sóc (beneficiary). Map sang bảng people.beneficiaries.
/// Dữ liệu y tế nhạy cảm (health_history, allergies, chronic_conditions, medications) được
/// bảo vệ bằng Row-Level Security theo customer_id. Các cột jsonb giữ nguyên dạng string?.
/// </summary>
public sealed class Beneficiary : AggregateRoot
{
    private Beneficiary() { } // EF

    private Beneficiary(Guid id, Guid customerId, string fullName) : base(id)
    {
        CustomerId = customerId;
        FullName = fullName;
    }

    public Guid CustomerId { get; private set; }
    public bool IsSelf { get; private set; }
    public long HealthProfileRevision { get; private set; } = 1;
    public string FoodAllergyStatus { get; private set; } = "unknown";
    public DateTimeOffset? FoodAllergyConfirmedAt { get; private set; }
    public Guid? FoodAllergyConfirmedBy { get; private set; }
    public string FullName { get; private set; } = null!;
    public DateOnly? DateOfBirth { get; private set; }

    /// <summary>Allowed values: MALE, FEMALE, OTHER, UNSPECIFIED.</summary>
    public string? Gender { get; private set; }
    public string? RelationshipToCustomer { get; private set; }
    public string? Phone { get; private set; }
    public Guid? DefaultAddressId { get; private set; }
    public string? MobilityNote { get; private set; }
    public string? GeneralNote { get; private set; }

    /// <summary>jsonb: gom beneficiary_health_profiles.</summary>
    public string? HealthHistory { get; private set; }

    /// <summary>jsonb.</summary>
    public string? Allergies { get; private set; }

    /// <summary>jsonb.</summary>
    public string? ChronicConditions { get; private set; }
    public string? CareInstructions { get; private set; }
    public string? CareLevel { get; private set; }
    public string? AvatarUrl { get; private set; }

    /// <summary>jsonb: gom emergency_contacts.</summary>
    public string? EmergencyContacts { get; private set; }

    /// <summary>jsonb: [{name,dosage,schedule,instruction,start_date,end_date,is_active}].</summary>
    public string? Medications { get; private set; }

    public DateTimeOffset? DeletedAt { get; private set; }

    public static Result<Beneficiary> Create(Guid customerId, string fullName)
    {
        if (customerId == Guid.Empty)
            return Error.Validation("beneficiary.customer", "customer_id là bắt buộc.");
        if (string.IsNullOrWhiteSpace(fullName))
            return Error.Validation("beneficiary.full_name", "full_name là bắt buộc.");

        return new Beneficiary(Guid.NewGuid(), customerId, fullName);
    }

    public Result Update(string fullName, DateOnly? dateOfBirth, string? gender,
        string? relationship, string? phone, Guid? defaultAddressId, string? mobilityNote,
        string? generalNote, string? healthHistory, string? allergies, string? chronicConditions,
        string? careInstructions, string? careLevel, string? avatarUrl,
        string? emergencyContacts, string? medications)
    {
        if (string.IsNullOrWhiteSpace(fullName) || fullName.Trim().Length > 255)
            return Error.Validation("beneficiary.full_name", "Họ tên không hợp lệ.");

        if (IsSelf && relationship?.Trim() != "Bản thân")
            return Error.Validation("beneficiary.self_relationship", "Không thể đổi quan hệ của hồ sơ bản thân.");

        var normalizedCareLevel = string.IsNullOrWhiteSpace(careLevel) ? null : careLevel.Trim();
        if (normalizedCareLevel is not null &&
            normalizedCareLevel is not ("Nhẹ" or "Trung bình" or "Nặng"))
            return Error.Validation("beneficiary.care_level", "Mức độ chăm sóc không hợp lệ.");

        var normalizedAvatarUrl = string.IsNullOrWhiteSpace(avatarUrl) ? null : avatarUrl.Trim();
        if (normalizedAvatarUrl is not null &&
            (!Uri.TryCreate(normalizedAvatarUrl, UriKind.Absolute, out var avatarUri) ||
             avatarUri.Scheme is not ("http" or "https")))
            return Error.Validation("beneficiary.avatar_url", "URL ảnh đại diện không hợp lệ.");

        FullName = fullName.Trim();
        DateOfBirth = dateOfBirth;
        Gender = gender;
        RelationshipToCustomer = relationship?.Trim();
        Phone = phone?.Trim();
        DefaultAddressId = defaultAddressId;
        MobilityNote = mobilityNote?.Trim();
        GeneralNote = generalNote?.Trim();
        HealthHistory = healthHistory;
        Allergies = allergies;
        ChronicConditions = chronicConditions;
        CareInstructions = careInstructions?.Trim();
        CareLevel = normalizedCareLevel;
        AvatarUrl = normalizedAvatarUrl;
        EmergencyContacts = emergencyContacts;
        Medications = medications;
        return Result.Success();
    }

    public Result MarkAsSelf()
    {
        if (DeletedAt is not null)
            return Error.Conflict("beneficiary.self_archived", "Hồ sơ đã ngừng hoạt động.");
        IsSelf = true;
        RelationshipToCustomer = "Bản thân";
        return Result.Success();
    }

    public Result UpdateHealth(long expectedRevision, string? generalNote, string? careInstructions,
        string? healthHistory, string? allergies, string? chronicConditions, string? medications,
        string allergyStatus, Guid actorId, DateTimeOffset now, bool confirmAllergy = false)
    {
        if (HealthProfileRevision != expectedRevision)
            return Error.Conflict("nutrition.profile_changed", "Thông tin sức khỏe đã thay đổi. Vui lòng kiểm tra lại.");
        if (allergyStatus is not ("unknown" or "reported_present" or "reported_none"))
            return Error.Validation("nutrition.allergy_status", "Trạng thái dị ứng không hợp lệ.");
        GeneralNote = generalNote;
        CareInstructions = careInstructions;
        HealthHistory = healthHistory;
        Allergies = allergies;
        ChronicConditions = chronicConditions;
        Medications = medications;
        FoodAllergyStatus = allergyStatus;
        if (allergyStatus == "unknown" || confirmAllergy)
        {
            FoodAllergyConfirmedAt = allergyStatus == "unknown" ? null : now;
            FoodAllergyConfirmedBy = allergyStatus == "unknown" ? null : actorId;
        }
        return Result.Success();
    }

    public Result Delete(DateTimeOffset deletedAt)
    {
        if (IsSelf)
            return Error.Conflict("beneficiary.self_managed", "Vui lòng sửa thông tin chăm sóc của tôi thay vì xóa hồ sơ.");
        DeletedAt = deletedAt;
        return Result.Success();
    }
}
