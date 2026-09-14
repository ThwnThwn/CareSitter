using CareSitter.Infrastructure.Security;
using CareSitter.Modules.People.Domain;
using CareSitter.Modules.People.Infrastructure;
using CareSitter.SharedKernel.Results;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using System.Text.Json;

namespace CareSitter.Modules.People.Controllers;

/// <summary>
/// Quản lý hồ sơ (KYC) và thông tin cá nhân của Caregiver.
/// </summary>
[ApiController]
[Authorize]
public sealed class CaregiverKycController(
    PeopleDbContext db, ICurrentUser currentUser, IEncryptionService encryption) : ControllerBase
{
    /// <summary>
    /// Tạo hồ sơ caregiver cho tài khoản CAREGIVER hiện tại.
    /// Endpoint idempotent để app có thể tự phục hồi tài khoản cũ còn thiếu profile.
    /// </summary>
    [HttpPost("api/v1/caregivers/me/profile")]
    public async Task<IActionResult> CreateMyProfile(
        [FromBody] CreateCaregiverProfileRequest req, CancellationToken ct)
    {
        if (currentUser.UserId is not { } userId) return Unauthorized();
        if (!currentUser.IsInRole("CAREGIVER")) return Forbid();

        var existing = await db.CaregiverProfiles
            .SingleOrDefaultAsync(x => x.UserId == userId && x.DeletedAt == null, ct);
        if (existing is not null)
            return Ok(ToProfileResponse(existing));

        var created = CaregiverProfile.Create(userId);
        if (created.IsFailure) return Problem(created.Error);
        var updated = created.Value.UpdateProfile(fullName: req.FullName?.Trim());
        if (updated.IsFailure) return Problem(updated.Error);

        db.CaregiverProfiles.Add(created.Value);
        try
        {
            await db.SaveChangesAsync(ct);
        }
        catch (DbUpdateException)
        {
            // Hai request khởi tạo đồng thời có thể cùng vượt qua bước kiểm tra ở trên.
            // Unique constraint theo UserId quyết định request thắng; request còn lại trả
            // về profile vừa được tạo để endpoint vẫn thực sự idempotent.
            db.ChangeTracker.Clear();
            var concurrentlyCreated = await db.CaregiverProfiles.AsNoTracking()
                .SingleOrDefaultAsync(x => x.UserId == userId && x.DeletedAt == null, ct);
            if (concurrentlyCreated is null) throw;

            return Ok(ToProfileResponse(concurrentlyCreated));
        }

        return Created("/api/v1/caregivers/me/profile", ToProfileResponse(created.Value));
    }

    /// <summary>
    /// Caregiver xem hồ sơ của chính mình theo JWT hiện tại.
    /// Dùng cho app caregiver để hiển thị đúng tên, rating, kỹ năng, khu vực và id profile.
    /// </summary>
    [HttpGet("api/v1/caregivers/me/profile")]
    public async Task<IActionResult> GetMyProfile(CancellationToken ct)
    {
        if (currentUser.UserId is not { } userId) return Unauthorized();

        var profile = await db.CaregiverProfiles.AsNoTracking()
            .SingleOrDefaultAsync(x => x.UserId == userId && x.DeletedAt == null, ct);
        if (profile is null)
            return NotFound(new { error = "Caregiver profile khong ton tai." });

        string? avatarUrl = null;
        try
        {
            avatarUrl = await db.Database
                .SqlQueryRaw<string>("SELECT avatar_url AS \"Value\" FROM identity.users WHERE id = {0}", userId)
                .FirstOrDefaultAsync(ct);
        }
        catch
        {
            // fallback if cross-schema query fails
        }

        return Ok(ToProfileResponse(profile, avatarUrl));
    }

    /// <summary>
    /// Caregiver nộp hồ sơ KYC (xác minh danh tính).
    /// Số CCCD được mã hóa AES (lưu vào DB) và tính HMAC (dùng kiểm tra trùng lặp) trước khi lưu.
    /// Sau khi nộp, trạng thái KYC chuyển sang PENDING — chờ Admin duyệt.
    /// </summary>
    /// <param name="req">Số CCCD gốc (plaintext) và danh sách URL chứng chỉ (tùy chọn).</param>
    /// <param name="ct">Token hủy tác vụ bất đồng bộ.</param>
    /// <returns>200 OK kèm trạng thái KYC mới sau khi nộp.</returns>
    [HttpPost("api/v1/caregivers/me/kyc")]
    public async Task<IActionResult> SubmitKyc([FromBody] SubmitKycRequest req, CancellationToken ct)
    {
        if (currentUser.UserId is not { } userId) return Unauthorized();

        var profile = await db.CaregiverProfiles
            .SingleOrDefaultAsync(x => x.UserId == userId && x.DeletedAt == null, ct);
        if (profile is null)
            return NotFound(new { error = "Caregiver profile khong ton tai." });

        var cccdNumber = req.CccdNumber?.Trim() ?? string.Empty;
        if (cccdNumber.Length is not (9 or 12) || !cccdNumber.All(char.IsDigit))
            return BadRequest(new { error = "So CCCD phai gom 9 hoac 12 chu so." });
        if (!IsHttpUrl(req.CccdFrontUrl) || !IsHttpUrl(req.CccdBackUrl))
            return BadRequest(new { error = "Anh mat truoc va mat sau CCCD phai co URL hop le." });

        var certificateUrls = (req.CertificateUrls ?? Array.Empty<string>())
            .Where(x => !string.IsNullOrWhiteSpace(x))
            .Select(x => x.Trim())
            .Distinct(StringComparer.OrdinalIgnoreCase)
            .ToArray();
        if (certificateUrls.Length > 10 || certificateUrls.Any(x => !IsHttpUrl(x)))
            return BadRequest(new { error = "Danh sach chung chi khong hop le hoac vuot qua 10 tep." });

        var cccdEncrypted = encryption.Encrypt(cccdNumber);
        var cccdHash = encryption.Hmac(cccdNumber);

        var result = profile.SubmitKyc(
            cccdEncrypted,
            cccdHash,
            req.CccdFrontUrl.Trim(),
            req.CccdBackUrl.Trim(),
            JsonSerializer.Serialize(certificateUrls));
        if (result.IsFailure) return Problem(result.Error);

        await db.SaveChangesAsync(ct);
        return Ok(new
        {
            kycStatus = profile.KycStatus,
            profile.CccdFrontUrl,
            profile.CccdBackUrl,
            CertificateUrls = certificateUrls,
            message = "Hồ sơ KYC đã được nộp."
        });
    }

    /// <summary>
    /// Caregiver cập nhật thông tin hồ sơ cá nhân (bio, kỹ năng, giá dịch vụ, khu vực phục vụ).
    /// Chỉ Caregiver của profile đó mới có quyền cập nhật (kiểm tra qua JWT).
    /// Không ảnh hưởng đến trạng thái KYC.
    /// </summary>
    /// <param name="req">Các trường cần cập nhật (FullName, Bio, YearsOfExperience, HourlyRateExpected, Skills, ServiceCity, ServiceDistrict, Gender, DateOfBirth).</param>
    /// <param name="ct">Token hủy tác vụ bất đồng bộ.</param>
    /// <returns>200 OK kèm thông tin profile sau khi cập nhật.</returns>
    [HttpPut("api/v1/caregivers/me/profile")]
    public async Task<IActionResult> UpdateMyProfile([FromBody] UpdateCaregiverProfileRequest req, CancellationToken ct)
    {
        if (currentUser.UserId is not { } userId) return Unauthorized();

        var profile = await db.CaregiverProfiles
            .SingleOrDefaultAsync(x => x.UserId == userId && x.DeletedAt == null, ct);
        if (profile is null)
            return NotFound(new { error = "Caregiver profile khong ton tai." });

        var result = profile.UpdateProfile(
            fullName: req.FullName, bio: req.Bio,
            yearsOfExperience: req.YearsOfExperience,
            hourlyRateExpected: req.HourlyRateExpected,
            skills: req.Skills, serviceCity: req.ServiceCity,
            serviceDistrict: req.ServiceDistrict,
            gender: req.Gender, dateOfBirth: req.DateOfBirth);
        if (result.IsFailure) return Problem(result.Error);

        await db.SaveChangesAsync(ct);
        return Ok(new
        {
            profile.Id,
            profile.FullName,
            profile.Bio,
            profile.YearsOfExperience,
            profile.HourlyRateExpected,
            profile.KycStatus,
            profile.AvailabilityStatus,
            profile.ServiceCity,
            profile.ServiceDistrict,
            profile.Gender,
            DateOfBirth = profile.DateOfBirth?.ToString("yyyy-MM-dd"),
            profile.Skills
        });
    }

    /// <summary>
    /// Caregiver cập nhật trạng thái sẵn sàng nhận việc (ONLINE, OFFLINE, BUSY).
    /// </summary>
    [HttpPut("api/v1/caregivers/me/status")]
    public async Task<IActionResult> UpdateMyAvailabilityStatus(
        [FromBody] UpdateCaregiverStatusRequest req, CancellationToken ct)
    {
        if (currentUser.UserId is not { } userId) return Unauthorized();

        var profile = await db.CaregiverProfiles
            .SingleOrDefaultAsync(x => x.UserId == userId && x.DeletedAt == null, ct);
        if (profile is null)
            return NotFound(new { error = "Caregiver profile khong ton tai." });

        var result = profile.SetAvailabilityStatus(req.Status);
        if (result.IsFailure) return Problem(result.Error);

        await db.SaveChangesAsync(ct);
        return Ok(new { profile.Id, profile.AvailabilityStatus });
    }

    /// <summary>Admin xem hàng đợi KYC cùng tài liệu đã nộp.</summary>
    [HttpGet("api/v1/caregivers/kyc")]
    public async Task<IActionResult> ListKyc(
        string? status = "PENDING", int page = 1, int pageSize = 20,
        CancellationToken ct = default)
    {
        if (!currentUser.IsInRole("ADMIN")) return Forbid();
        page = Math.Max(page, 1);
        pageSize = Math.Clamp(pageSize, 1, 50);

        var query = db.CaregiverProfiles.AsNoTracking()
            .Where(x => x.DeletedAt == null);
        if (!string.IsNullOrWhiteSpace(status))
        {
            var normalizedStatus = status.Trim().ToUpperInvariant();
            query = query.Where(x => x.KycStatus == normalizedStatus);
        }

        var total = await query.CountAsync(ct);
        var profiles = await query.OrderByDescending(x => x.UpdatedAt)
            .Skip((page - 1) * pageSize)
            .Take(pageSize)
            .ToListAsync(ct);

        return Ok(new
        {
            items = profiles.Select(ToKycResponse),
            total,
            page,
            pageSize
        });
    }

    /// <summary>Admin xem chi tiết một hồ sơ KYC trước khi duyệt.</summary>
    [HttpGet("api/v1/caregivers/{id:guid}/kyc")]
    public async Task<IActionResult> GetKyc(Guid id, CancellationToken ct)
    {
        if (!currentUser.IsInRole("ADMIN")) return Forbid();
        var profile = await db.CaregiverProfiles.AsNoTracking()
            .SingleOrDefaultAsync(x => x.Id == id && x.DeletedAt == null, ct);
        return profile is null ? NotFound() : Ok(ToKycResponse(profile));
    }

    /// <summary>
    /// Admin duyệt hồ sơ KYC của caregiver, chuyển trạng thái sang APPROVED.
    /// Sau khi APPROVED, caregiver có thể xuất hiện trong danh sách tìm kiếm và nhận ca.
    /// Chỉ tài khoản mang role ADMIN mới có quyền gọi endpoint này.
    /// </summary>
    /// <param name="id">ID của CaregiverProfile cần duyệt.</param>
    /// <param name="ct">Token hủy tác vụ bất đồng bộ.</param>
    /// <returns>200 OK kèm ID và trạng thái KYC mới (APPROVED).</returns>
    [HttpPost("api/v1/caregivers/{id:guid}/kyc/approve")]
    public async Task<IActionResult> ApproveKyc(Guid id, CancellationToken ct)
    {
        if (!currentUser.IsInRole("ADMIN")) return Forbid();

        var profile = await db.CaregiverProfiles
            .SingleOrDefaultAsync(x => x.Id == id && x.DeletedAt == null, ct);
        if (profile is null) return NotFound();

        var result = profile.ApproveKyc();
        if (result.IsFailure) return Problem(result.Error);

        await db.SaveChangesAsync(ct);
        return Ok(new { profile.Id, profile.KycStatus });
    }

    /// <summary>
    /// Admin từ chối hồ sơ KYC của caregiver, chuyển trạng thái sang REJECTED.
    /// Caregiver có thể nộp lại hồ sơ sau khi bị từ chối.
    /// Chỉ tài khoản mang role ADMIN mới có quyền gọi endpoint này.
    /// </summary>
    /// <param name="id">ID của CaregiverProfile cần từ chối.</param>
    /// <param name="req">Lý do từ chối (tùy chọn, gửi cho caregiver biết).</param>
    /// <param name="ct">Token hủy tác vụ bất đồng bộ.</param>
    /// <returns>200 OK kèm ID, trạng thái KYC mới (REJECTED) và lý do.</returns>
    [HttpPost("api/v1/caregivers/{id:guid}/kyc/reject")]
    public async Task<IActionResult> RejectKyc(Guid id, [FromBody] RejectKycRequest? req, CancellationToken ct)
    {
        if (!currentUser.IsInRole("ADMIN")) return Forbid();

        var profile = await db.CaregiverProfiles
            .SingleOrDefaultAsync(x => x.Id == id && x.DeletedAt == null, ct);
        if (profile is null) return NotFound();

        var result = profile.RejectKyc();
        if (result.IsFailure) return Problem(result.Error);

        await db.SaveChangesAsync(ct);
        return Ok(new { profile.Id, profile.KycStatus, reason = req?.Reason });
    }

    private IActionResult Problem(Error error) => error.Type switch
    {
        ErrorType.NotFound => NotFound(new ProblemDetails { Title = error.Code, Detail = error.Message }),
        ErrorType.Conflict => Conflict(new ProblemDetails { Title = error.Code, Detail = error.Message }),
        ErrorType.Forbidden => Forbid(),
        _ => BadRequest(new ProblemDetails { Title = error.Code, Detail = error.Message })
    };

    private static bool IsHttpUrl(string? value) =>
        Uri.TryCreate(value, UriKind.Absolute, out var uri)
        && uri.Scheme is "http" or "https";

    private static string[] DeserializeUrls(string? json)
    {
        if (string.IsNullOrWhiteSpace(json)) return Array.Empty<string>();
        try { return JsonSerializer.Deserialize<string[]>(json) ?? Array.Empty<string>(); }
        catch (JsonException) { return Array.Empty<string>(); }
    }

    private static object ToKycResponse(CaregiverProfile profile) => new
    {
        profile.Id,
        profile.UserId,
        profile.FullName,
        profile.DateOfBirth,
        profile.Gender,
        profile.KycStatus,
        profile.CccdFrontUrl,
        profile.CccdBackUrl,
        CertificateUrls = DeserializeUrls(profile.CertificateUrls),
        profile.CreatedAt,
        profile.UpdatedAt
    };

    private static object ToProfileResponse(CaregiverProfile profile, string? avatarUrl = null) => new
    {
        profile.Id,
        profile.UserId,
        profile.FullName,
        profile.Gender,
        DateOfBirth = profile.DateOfBirth?.ToString("yyyy-MM-dd"),
        profile.Bio,
        profile.YearsOfExperience,
        profile.HourlyRateExpected,
        profile.RatingAvg,
        profile.RatingCount,
        profile.KycStatus,
        profile.CccdFrontUrl,
        profile.CccdBackUrl,
        CertificateUrls = DeserializeUrls(profile.CertificateUrls),
        profile.AvailabilityStatus,
        profile.Skills,
        profile.ServiceCity,
        profile.ServiceDistrict,
        AvatarUrl = avatarUrl
    };
}

public sealed record CreateCaregiverProfileRequest(string? FullName = null);
public sealed record SubmitKycRequest(
    string CccdNumber,
    string CccdFrontUrl,
    string CccdBackUrl,
    string[]? CertificateUrls = null);
public sealed record RejectKycRequest(string? Reason);
public sealed record UpdateCaregiverStatusRequest(string Status);
public sealed record UpdateCaregiverProfileRequest(
    string? FullName = null, string? Bio = null, int? YearsOfExperience = null,
    long? HourlyRateExpected = null, string? Skills = null,
    string? ServiceCity = null, string? ServiceDistrict = null,
    string? Gender = null, DateOnly? DateOfBirth = null);
