using CareSitter.Modules.Identity.Application;
using CareSitter.Contracts.Services;
using CareSitter.Modules.Identity.Domain;
using CareSitter.Modules.Identity.Application.Login;
using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Identity.Application.Register;

/// <summary>
/// Bộ xử lý yêu cầu đăng ký tài khoản người dùng mới.
/// </summary>
internal sealed class RegisterHandler : IRequestHandler<RegisterCommand, Result<LoginResponse>>
{
    private readonly IIdentityStore _store;
    private readonly ICaregiverRegistrationService _caregiverRegistration;
    private readonly IRefreshTokenSessionService _sessions;

    // Endpoint đăng ký là public nên tuyệt đối không cho tự cấp quyền ADMIN.
    private static readonly string[] AllowedRoles = { "CUSTOMER", "CAREGIVER" };

    /// <summary>
    /// Khởi tạo RegisterHandler với các cổng lưu trữ và phát hành session.
    /// </summary>
    public RegisterHandler(
        IIdentityStore store,
        ICaregiverRegistrationService caregiverRegistration,
        IRefreshTokenSessionService sessions,
        IPasswordHasher passwordHasher)
    {
        _store = store;
        _caregiverRegistration = caregiverRegistration;
        _sessions = sessions;
        _passwordHasher = passwordHasher;
    }

    private readonly IPasswordHasher _passwordHasher;

    /// <summary>
    /// Xử lý việc kiểm tra tính duy nhất của số điện thoại, hợp lệ của vai trò, lưu người dùng mới và phát hành JWT tokens.
    /// </summary>
    public async Task<Result<LoginResponse>> Handle(RegisterCommand request, CancellationToken ct)
    {
        var email = request.Email?.Trim().ToLowerInvariant() ?? string.Empty;
        var phone = request.Phone?.Trim();

        if (string.IsNullOrWhiteSpace(email))
        {
            return Error.Validation("auth.email_required", "Email là bắt buộc.");
        }

        if (string.IsNullOrWhiteSpace(request.FullName))
        {
            return Error.Validation("auth.fullname_required", "Họ tên là bắt buộc.");
        }

        if (request.Roles == null || request.Roles.Length == 0)
        {
            return Error.Validation("auth.roles_required", "Vai trò là bắt buộc.");
        }

        // Validate password nếu được cung cấp (tối thiểu 8 ký tự, 1 chữ hoa, 1 chữ số)
        if (request.Password is not null)
        {
            var pwd = request.Password;
            if (pwd.Length < 8 ||
                !pwd.Any(char.IsUpper) ||
                !pwd.Any(char.IsDigit))
            {
                return Error.Validation("auth.weak_password",
                    "Mật khẩu phải có ít nhất 8 ký tự, bao gồm 1 chữ hoa và 1 chữ số.");
            }

            // ConfirmPassword phải được cung cấp và khớp với Password
            if (request.ConfirmPassword is null)
                return Error.Validation("auth.confirm_password_required", "Vui lòng xác nhận lại mật khẩu.");

            if (request.Password != request.ConfirmPassword)
                return Error.Validation("auth.password_mismatch", "Mật khẩu xác nhận không khớp.");
        }

        // Kiểm tra tính hợp lệ của vai trò
        foreach (var role in request.Roles)
        {
            if (!AllowedRoles.Contains(role.ToUpper()))
            {
                return Error.Validation("auth.invalid_role", $"Vai trò '{role}' không hợp lệ. Các vai trò cho phép: CUSTOMER, CAREGIVER.");
            }
        }

        // Kiểm tra trùng Email / Phone theo partial unique indexes của DB.
        var emailExists = await _store.EmailExistsAsync(email, ct: ct);
        if (emailExists)
        {
            return Error.Conflict("auth.email_exists", $"Email {email} đã được đăng ký.");
        }

        if (!string.IsNullOrWhiteSpace(phone))
        {
            var phoneExists = await _store.PhoneExistsAsync(phone, ct);
            if (phoneExists)
                return Error.Conflict("auth.phone_exists", $"Số điện thoại {phone} đã được đăng ký.");
        }

        // Tạo mới User
        var userResult = User.Create(Guid.NewGuid(), email);
        if (userResult.IsFailure)
        {
            return userResult.Error;
        }

        var user = userResult.Value;
        user.UpdateProfile(request.FullName, email, request.FullName);
        user.SetRoles(request.Roles.Select(r => r.ToUpper()).ToArray());
        if (!string.IsNullOrWhiteSpace(phone))
        {
            user.SetPhone(phone);
        }

        // Hash và lưu password nếu được cung cấp
        if (request.Password is not null)
        {
            var hash = _passwordHasher.Hash(request.Password);
            user.SetPassword(hash);
        }

        _store.AddUser(user);
        await _store.SaveChangesAsync(ct);

        // Tự động tạo CaregiverProfile nếu user đăng ký với vai trò CAREGIVER.
        if (user.Roles.Contains("CAREGIVER", StringComparer.OrdinalIgnoreCase))
        {
            await _caregiverRegistration.EnsureProfileAsync(user.Id, request.FullName, ct);
        }

        var tokens = await _sessions.IssueAsync(user, ct);
        return new LoginResponse(tokens.AccessToken, tokens.RefreshToken, user.Id, user.Roles, user.DisplayName);
    }
}
