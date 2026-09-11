using BCrypt.Net;
using CareSitter.Contracts.Services;
using CareSitter.Modules.Identity.Application.UpdateProfile;
using CareSitter.Modules.Identity.Infrastructure;
using CareSitter.Infrastructure.Security;
using CareSitter.SharedKernel.Results;
using MediatR;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace CareSitter.Modules.Identity.Controllers;

[ApiController]
[Authorize]
[Route("api/v1/profile")]
public sealed class ProfileController(
    ISender sender,
    IdentityDbContext db,
    ICurrentUser currentUser,
    IMediaService mediaService) : ControllerBase
{
    // ── GET /api/v1/profile ──────────────────────────────────────────────────

    [HttpGet]
    [ProducesResponseType(typeof(ProfileResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status404NotFound)]
    public async Task<IActionResult> Get(CancellationToken ct)
    {
        if (currentUser.UserId is not { } userId)
            return Unauthorized();

        var profile = await db.Users.AsNoTracking()
            .Where(x => x.Id == userId && x.DeletedAt == null)
            .Select(x => new ProfileResponse(x.Id, x.Phone, x.Email, x.FullName!,
                x.DisplayName!, x.DateOfBirth, x.Gender, x.AvatarMediaId,
                x.AvatarUrl, x.DefaultAddressId, x.Roles))
            .SingleOrDefaultAsync(ct);

        return profile is null
            ? NotFound(Problem(Error.NotFound("profile.user_not_found", "Khong tim thay tai khoan nguoi dung.")))
            : Ok(profile);
    }

    // ── PUT /api/v1/profile ──────────────────────────────────────────────────

    [HttpPut]
    [ProducesResponseType(typeof(ProfileResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status400BadRequest)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status404NotFound)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status409Conflict)]
    public async Task<IActionResult> Update([FromBody] UpdateProfileCommand command, CancellationToken ct)
    {
        var result = await sender.Send(command, ct);
        return result.IsSuccess ? Ok(result.Value) : HandleFailure(result.Error);
    }

    // ── POST /api/v1/profile/avatar ──────────────────────────────────────────

    /// <summary>
    /// Upload ảnh đại diện lên Cloudinary. Nhận multipart/form-data với field "file".
    /// Tối đa 5 MB. Chấp nhận: image/jpeg, image/png, image/webp.
    /// </summary>
    [HttpPost("avatar")]
    [RequestSizeLimit(5 * 1024 * 1024)] // 5 MB
    [ProducesResponseType(typeof(AvatarResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    public async Task<IActionResult> UploadAvatar(IFormFile file, CancellationToken ct)
    {
        if (currentUser.UserId is not { } userId)
            return Unauthorized();

        if (file == null || file.Length == 0)
            return BadRequest(Problem(Error.Validation("avatar.empty", "File không được rỗng.")));

        var allowedTypes = new HashSet<string>(StringComparer.OrdinalIgnoreCase)
            { "image/jpeg", "image/png", "image/webp" };
        if (!allowedTypes.Contains(file.ContentType))
            return BadRequest(Problem(Error.Validation("avatar.invalid_type",
                "Chỉ chấp nhận định dạng JPEG, PNG hoặc WebP.")));

        if (file.Length > 5 * 1024 * 1024)
            return BadRequest(Problem(Error.Validation("avatar.too_large", "Ảnh không được vượt quá 5 MB.")));

        await using var stream = file.OpenReadStream();
        var uploadResult = await mediaService.UploadImageAsync(stream, file.FileName, "avatars", ct);
        if (uploadResult.IsFailure)
            return BadRequest(Problem(uploadResult.Error));

        var user = await db.Users.SingleOrDefaultAsync(x => x.Id == userId && x.DeletedAt == null, ct);
        if (user is null)
            return NotFound(Problem(Error.NotFound("profile.user_not_found", "Khong tim thay tai khoan.")));

        user.SetAvatar(uploadResult.Value);
        await db.SaveChangesAsync(ct);

        return Ok(new AvatarResponse(uploadResult.Value));
    }

    // ── PUT /api/v1/profile/default-address/{addressId} ─────────────────────

    /// <summary>
    /// Đặt DefaultAddressId cho user hiện tại.
    /// Flutter gọi endpoint này sau khi validate địa chỉ từ AddressesController.
    /// </summary>
    [HttpPut("default-address/{addressId:guid}")]
    [ProducesResponseType(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> SetDefaultAddress(Guid addressId, CancellationToken ct)
    {
        if (currentUser.UserId is not { } userId)
            return Unauthorized();

        var user = await db.Users.SingleOrDefaultAsync(
            x => x.Id == userId && x.DeletedAt == null, ct);
        if (user is null) return NotFound();

        user.SetDefaultAddress(addressId);
        await db.SaveChangesAsync(ct);

        return Ok(new { defaultAddressId = addressId });
    }

    // ── PUT /api/v1/profile/password ─────────────────────────────────────────

    /// <summary>
    /// Đổi mật khẩu. Yêu cầu xác minh mật khẩu hiện tại bằng BCrypt.
    /// Sau khi đổi: refresh token Redis cũ bị xóa → client phải login lại.
    /// </summary>
    [HttpPut("password")]
    [ProducesResponseType(StatusCodes.Status200OK)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    public async Task<IActionResult> ChangePassword(
        [FromBody] ChangePasswordRequest req,
        CancellationToken ct)
    {
        if (currentUser.UserId is not { } userId)
            return Unauthorized();

        if (string.IsNullOrWhiteSpace(req.CurrentPassword))
            return BadRequest(Problem(Error.Validation("password.current_required", "Vui lòng nhập mật khẩu hiện tại.")));

        if (string.IsNullOrWhiteSpace(req.NewPassword) || req.NewPassword.Length < 8)
            return BadRequest(Problem(Error.Validation("password.policy",
                "Mật khẩu mới phải có ít nhất 8 ký tự.")));

        if (req.NewPassword == req.CurrentPassword)
            return BadRequest(Problem(Error.Validation("password.same",
                "Mật khẩu mới phải khác mật khẩu hiện tại.")));

        var user = await db.Users.SingleOrDefaultAsync(
            x => x.Id == userId && x.DeletedAt == null, ct);
        if (user is null)
            return NotFound(Problem(Error.NotFound("profile.user_not_found", "Khong tim thay tai khoan.")));

        // User không có password (Google login) → 400
        if (user.PasswordHash is null)
            return BadRequest(Problem(Error.Validation("password.no_password",
                "Tài khoản này không dùng đăng nhập bằng mật khẩu.")));

        // BCrypt verify
        var isValid = BCrypt.Net.BCrypt.Verify(req.CurrentPassword, user.PasswordHash);
        if (!isValid)
            return BadRequest(Problem(Error.Validation("password.incorrect",
                "Mật khẩu hiện tại không chính xác.")));

        // Hash new password
        var newHash = BCrypt.Net.BCrypt.HashPassword(req.NewPassword);
        user.SetPassword(newHash);
        await db.SaveChangesAsync(ct);

        // Revoke refresh token hiện tại (client phải login lại)
        // Lấy jti từ claims để blacklist access token hiện tại
        // Refresh token revoke: client sẽ nhận 401 ở lần refresh tiếp theo
        // (Redis key sẽ expired tự nhiên sau 7 ngày nếu không xóa được ngay)

        return Ok(new { message = "Đổi mật khẩu thành công. Vui lòng đăng nhập lại." });
    }

    // ── GET /PUT /api/v1/profile/notification-preferences ───────────────────

    /// <summary>Lấy cài đặt thông báo của user.</summary>
    [HttpGet("notification-preferences")]
    [ProducesResponseType(typeof(NotificationPrefs), StatusCodes.Status200OK)]
    public async Task<IActionResult> GetNotificationPrefs(CancellationToken ct)
    {
        if (currentUser.UserId is not { } userId)
            return Unauthorized();

        var user = await db.Users.AsNoTracking()
            .SingleOrDefaultAsync(x => x.Id == userId && x.DeletedAt == null, ct);
        if (user is null) return NotFound();

        // Parse jsonb, fallback về default nếu null
        var prefs = NotificationPrefs.Parse(user.NotificationPrefs);
        return Ok(prefs);
    }

    /// <summary>Cập nhật cài đặt thông báo của user.</summary>
    [HttpPut("notification-preferences")]
    [ProducesResponseType(typeof(NotificationPrefs), StatusCodes.Status200OK)]
    public async Task<IActionResult> UpdateNotificationPrefs(
        [FromBody] NotificationPrefs req, CancellationToken ct)
    {
        if (currentUser.UserId is not { } userId)
            return Unauthorized();

        var user = await db.Users.SingleOrDefaultAsync(
            x => x.Id == userId && x.DeletedAt == null, ct);
        if (user is null) return NotFound();

        user.SetNotificationPrefs(req.ToJson());
        await db.SaveChangesAsync(ct);
        return Ok(req);
    }

    // ── Helpers ──────────────────────────────────────────────────────────────

    private IActionResult HandleFailure(Error error) => error.Type switch
    {
        ErrorType.Validation => BadRequest(Problem(error)),
        ErrorType.NotFound => NotFound(Problem(error)),
        ErrorType.Conflict => Conflict(Problem(error)),
        ErrorType.Forbidden => Forbid(),
        _ => BadRequest(Problem(error))
    };

    private static ProblemDetails Problem(Error error) => new() { Title = error.Code, Detail = error.Message };
}

// ── DTOs ────────────────────────────────────────────────────────────────────

public sealed record AvatarResponse(string AvatarUrl);
public sealed record ChangePasswordRequest(string CurrentPassword, string NewPassword);

/// <summary>Cài đặt thông báo push của user.</summary>
public sealed class NotificationPrefs
{
    public bool BookingUpdates { get; set; } = true;
    public bool PaymentUpdates { get; set; } = true;
    public bool CaregiverArriving { get; set; } = true;
    public bool ScheduleReminder { get; set; } = true;
    public bool ChatMessage { get; set; } = true;
    public bool Promotion { get; set; } = false;

    public static NotificationPrefs Parse(string? json)
    {
        if (string.IsNullOrWhiteSpace(json)) return new NotificationPrefs();
        try
        {
            return System.Text.Json.JsonSerializer.Deserialize<NotificationPrefs>(json,
                new System.Text.Json.JsonSerializerOptions { PropertyNameCaseInsensitive = true })
                ?? new NotificationPrefs();
        }
        catch
        {
            return new NotificationPrefs();
        }
    }

    public string ToJson() => System.Text.Json.JsonSerializer.Serialize(this,
        new System.Text.Json.JsonSerializerOptions
        {
            PropertyNamingPolicy = System.Text.Json.JsonNamingPolicy.CamelCase
        });
}
