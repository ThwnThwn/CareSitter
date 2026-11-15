using CareSitter.SharedKernel.Domain;
using CareSitter.SharedKernel.Results;

namespace CareSitter.Modules.Identity.Domain;

/// <summary>
/// Aggregate root cho 1 người dùng. Gop customer_profiles + admin_profiles + user_roles.
/// Map sang bang users (schema identity).
/// </summary>
public sealed class User : AggregateRoot
{
    private User() { } // EF


    public string? Phone { get; private set; }
    public string Email { get; private set; } = null!;
    public DateTimeOffset? EmailVerifiedAt { get; private set; }
    public long RecoveryVersion { get; private set; }
    public string? DisplayName { get; private set; }
    public Guid? AvatarMediaId { get; private set; }
    /// <summary>URL ảnh đại diện trên Cloudinary. Ưu tiên dùng cái này để render.</summary>
    public string? AvatarUrl { get; private set; }

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

    /// <summary>jsonb: cài đặt thông báo push (serialized NotificationPrefs).</summary>
    public string? NotificationPrefs { get; private set; }

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
            ChangeEmail(email);
        }
        DisplayName = !string.IsNullOrWhiteSpace(displayName) ? displayName.Trim() : fullName?.Trim();
    }

    /// <summary>
    /// Updates the editable personal information of the user.
    /// </summary>
    public void UpdateProfile(
        string fullName,
        string email,
        string? displayName,
        DateOnly? dateOfBirth,
        string? gender)
    {
        FullName = fullName.Trim();
        ChangeEmail(email);
        DisplayName = string.IsNullOrWhiteSpace(displayName)
            ? FullName
            : displayName.Trim();
        DateOfBirth = dateOfBirth;
        Gender = gender;
    }

    /// <summary>
    /// Thiết lập danh sách vai trò (roles) cho người dùng.
    /// </summary>
    public void SetRoles(string[] roles)
    {
        if (!Roles.SequenceEqual(roles ?? Array.Empty<string>())) RecoveryVersion++;
        Roles = roles ?? Array.Empty<string>();
    }

    public Result SetStatus(string status)
    {
        var normalized = status?.Trim().ToUpperInvariant();
        if (normalized is not ("ACTIVE" or "SUSPENDED" or "LOCKED"))
            return Error.Validation("user.status", "Trạng thái phải là ACTIVE, SUSPENDED hoặc LOCKED.");

        if (Status != normalized) RecoveryVersion++;
        Status = normalized;
        return Result.Success();
    }

    /// <summary>
    /// Thiết lập số điện thoại cho người dùng.
    /// </summary>
    public void SetPhone(string? phone)
    {
        Phone = string.IsNullOrWhiteSpace(phone) ? null : phone.Trim();
    }

    /// <summary>
    /// Ghi nhận thời điểm đăng nhập gần nhất của người dùng.
    /// </summary>
    public void RecordLogin(DateTimeOffset time)
    {
        LastLoginAt = time;
    }

    /// <summary>
    /// Cập nhật URL ảnh đại diện (Cloudinary secure URL).
    /// </summary>
    /// <summary>
    /// Lưu cài đặt thông báo push (JSON string dạng camelCase).
    /// </summary>
    public void SetNotificationPrefs(string prefsJson)
    {
        NotificationPrefs = prefsJson;
    }

    public void SetAvatar(string avatarUrl)
    {
        AvatarUrl = string.IsNullOrWhiteSpace(avatarUrl) ? null : avatarUrl.Trim();
    }

    /// <summary>
    /// Thiết lập mật khẩu đã được hash bằng BCrypt cho tài khoản.
    /// </summary>
    public void SetPassword(string passwordHash)
    {
        PasswordHash = passwordHash;
        RecoveryVersion++;
    }

    public void VerifyEmail(DateTimeOffset time) => EmailVerifiedAt = time;

    public void ChangeEmail(string email)
    {
        var normalized = email.Trim().ToLowerInvariant();
        if (Email == normalized) return;
        Email = normalized;
        EmailVerifiedAt = null;
        RecoveryVersion++;
    }

    /// <summary>
    /// Đặt địa chỉ mặc định cho user (dùng khi booking).
    /// </summary>
    public void SetDefaultAddress(Guid addressId)
    {
        DefaultAddressId = addressId;
    }

    /// <summary>
    /// Liên kết tài khoản Google (Google Subject ID) với user này.
    /// </summary>
    public void LinkGoogle(string googleId)
    {
        GoogleId = googleId;
    }
}

