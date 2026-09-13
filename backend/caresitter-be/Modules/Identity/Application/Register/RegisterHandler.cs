using BCrypt.Net;
using CareSitter.Modules.Identity.Application.AuthSessions;
using CareSitter.Modules.Identity.Domain;
using CareSitter.Modules.Identity.Application.Login;
using CareSitter.Modules.Identity.Infrastructure;
using CareSitter.Modules.People.Domain;
using CareSitter.Modules.People.Infrastructure;
using CareSitter.SharedKernel.Results;
using MediatR;
using Microsoft.EntityFrameworkCore;

namespace CareSitter.Modules.Identity.Application.Register;

/// <summary>
/// Bộ xử lý yêu cầu đăng ký tài khoản người dùng mới.
/// </summary>
internal sealed class RegisterHandler : IRequestHandler<RegisterCommand, Result<LoginResponse>>
{
    private readonly IdentityDbContext _db;
    private readonly PeopleDbContext _peopleDb;
    private readonly RefreshTokenSessionService _sessions;

    // Endpoint đăng ký là public nên tuyệt đối không cho tự cấp quyền ADMIN.
    private static readonly string[] AllowedRoles = { "CUSTOMER", "CAREGIVER" };

    /// <summary>
    /// Khởi tạo RegisterHandler với DbContext, JWT token service và Redis cache.
    /// </summary>
    public RegisterHandler(
        IdentityDbContext db,
        PeopleDbContext peopleDb,
        RefreshTokenSessionService sessions)
    {
        _db = db;
        _peopleDb = peopleDb;
        _sessions = sessions;
    }

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
        var emailExists = await _db.Users.AnyAsync(u => u.Email == email && u.DeletedAt == null, ct);
        if (emailExists)
        {
            return Error.Conflict("auth.email_exists", $"Email {email} đã được đăng ký.");
        }

        if (!string.IsNullOrWhiteSpace(phone))
        {
            var phoneExists = await _db.Users.AnyAsync(u => u.Phone == phone && u.DeletedAt == null, ct);
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
            var hash = BCrypt.Net.BCrypt.HashPassword(request.Password, workFactor: 12);
            user.SetPassword(hash);
        }

        _db.Users.Add(user);
        await _db.SaveChangesAsync(ct);

        // Tự động tạo CaregiverProfile nếu user đăng ký với vai trò CAREGIVER.
        if (user.Roles.Contains("CAREGIVER", StringComparer.OrdinalIgnoreCase))
        {
            var profileResult = CaregiverProfile.Create(user.Id);
            if (profileResult.IsSuccess)
            {
                // Gán fullName ngay từ lúc đăng ký để profile không rỗng.
                profileResult.Value.UpdateProfile(fullName: request.FullName?.Trim());
                _peopleDb.CaregiverProfiles.Add(profileResult.Value);
                await _peopleDb.SaveChangesAsync(ct);
            }
        }

        var tokens = await _sessions.IssueAsync(user, ct);
        return new LoginResponse(tokens.AccessToken, tokens.RefreshToken, user.Id, user.Roles, user.DisplayName);
    }
}
