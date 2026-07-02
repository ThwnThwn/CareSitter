using CareSitter.SharedKernel.Domain;
using CareSitter.SharedKernel.Results;

namespace CareSitter.Modules.Identity.Domain;

/// <summary>
/// Aggregate root cho 1 nguoi dung. Gop customer_profiles + admin_profiles + user_roles.
/// Map sang bang users (schema identity).
/// </summary>
public sealed class User : AggregateRoot
{
    private User() { } // EF

    private User(Guid id, string phone) : base(id)
    {
        Phone = phone;
    }

    public string Phone { get; private set; } = null!;
    public string? Email { get; private set; }
    public string? DisplayName { get; private set; }
    public Guid? AvatarMediaId { get; private set; }

    /// <summary>Allowed values: ACTIVE, SUSPENDED, LOCKED, DELETED.</summary>
    public string Status { get; private set; } = "ACTIVE";

    /// <summary>Allowed values: CUSTOMER, CAREGIVER, ADMIN.</summary>
    public string[] Roles { get; private set; } = Array.Empty<string>();

    // customer fields
    public string? FullName { get; private set; }
    public DateOnly? DateOfBirth { get; private set; }

    /// <summary>Allowed values: MALE, FEMALE, OTHER, UNSPECIFIED.</summary>
    public string? Gender { get; private set; }
    public Guid? DefaultAddressId { get; private set; }

    // admin fields (chi set khi la admin)
    /// <summary>Allowed values: OPERATIONS, CSKH, ACCOUNTING, MANAGEMENT.</summary>
    public string? AdminDepartment { get; private set; }

    /// <summary>Allowed values: SUPER_ADMIN, OPERATIONS, CSKH, ACCOUNTING.</summary>
    public string? AdminRole { get; private set; }

    /// <summary>jsonb permissions blob.</summary>
    public string? AdminPermissions { get; private set; }
    public bool? AdminIsActive { get; private set; }

    public DateTimeOffset? LastLoginAt { get; private set; }
    public DateTimeOffset? DeletedAt { get; private set; }

    public static Result<User> Create(Guid id, string phone)
    {
        if (string.IsNullOrWhiteSpace(phone))
            return Error.Validation("user.phone", "phone la bat buoc.");

        return new User(id, phone.Trim());
    }
}
