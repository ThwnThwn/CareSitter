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


    public string? Phone { get; private set; }
    public string Email { get; private set; } = null!;
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

    /// <summary>BCrypt hash mật khẩu. Null nếu user không dùng password login.</summary>
    public string? PasswordHash { get; private set; }

    /// <summary>Google Subject ID ("sub" claim). Null nếu user không dùng Google login.</summary>
    public string? GoogleId { get; private set; }

    private User(Guid id, string email) : base(id)
    {
        Email = email;
    }

    public static Result<User> Create(Guid id, string email)
    {
        if (string.IsNullOrWhiteSpace(email))
            return Error.Validation("user.email", "Email là bắt buộc.");

        return new User(id, email.Trim().ToLowerInvariant());
    }

    /// <summary>
    /// Cập nhật thông tin hồ sơ cơ bản của người dùng.
    /// </summary>
    /// <param name="fullName">Họ và tên đầy đủ.</param>
    /// <param name="email">Địa chỉ email.</param>
    /// <param name="displayName">Tên hiển thị trên giao diện.</param>
    public void UpdateProfile(string? fullName, string? email, string? displayName)
    {
        FullName = fullName?.Trim();
        if (!string.IsNullOrWhiteSpace(email))
        {
            Email = email.Trim().ToLowerInvariant();
        }
        DisplayName = !string.IsNullOrWhiteSpace(displayName) ? displayName.Trim() : fullName?.Trim();
    }

    /// <summary>
    /// Thiết lập danh sách vai trò (roles) cho người dùng.
    /// </summary>
    /// <param name="roles">Mảng chứa các vai trò như CUSTOMER, CAREGIVER, ADMIN.</param>
    public void SetRoles(string[] roles)
    {
        Roles = roles ?? Array.Empty<string>();
    }

    /// <summary>
    /// Ghi nhận thời điểm đăng nhập gần nhất của người dùng.
    /// </summary>
    /// <param name="time">Thời điểm đăng nhập.</param>
    public void RecordLogin(DateTimeOffset time)
    {
        LastLoginAt = time;
    }

    /// <summary>
    /// Thiết lập mật khẩu đã được hash bằng BCrypt cho tài khoản.
    /// </summary>
    /// <param name="passwordHash">BCrypt hash của mật khẩu.</param>
    public void SetPassword(string passwordHash)
    {
        PasswordHash = passwordHash;
    }

    /// <summary>
    /// Liên kết tài khoản Google (Google Subject ID) với user này.
    /// </summary>
    /// <param name="googleId">Google Subject ID từ ID token.</param>
    public void LinkGoogle(string googleId)
    {
        GoogleId = googleId;
    }
}


