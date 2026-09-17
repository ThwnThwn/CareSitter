using CareSitter.Infrastructure.Security;
using CareSitter.Modules.People.Application.Commands.ApproveCaregiverKyc;
using CareSitter.Modules.People.Application.Commands.CreateCaregiverProfile;
using CareSitter.Modules.People.Application.Commands.RejectCaregiverKyc;
using CareSitter.Modules.People.Application.Commands.SubmitCaregiverKyc;
using CareSitter.Modules.People.Application.Commands.UpdateCaregiverAvailabilityStatus;
using CareSitter.Modules.People.Application.Commands.UpdateCaregiverProfile;
using CareSitter.Modules.People.Domain;
using CareSitter.Modules.People.Infrastructure;
using MediatR;
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
    PeopleDbContext db, ICurrentUser currentUser, ISender sender) : ControllerBase
{
    /// <summary>
    /// Tạo hồ sơ caregiver cho tài khoản CAREGIVER hiện tại.
    /// Endpoint idempotent để app có thể tự phục hồi tài khoản cũ còn thiếu profile.
    /// </summary>
    [HttpPost("api/v1/caregivers/me/profile")]
    public async Task<IActionResult> CreateMyProfile(
        [FromBody] CreateCaregiverProfileRequest req, CancellationToken ct)
    {
        var result = await sender.Send(new CreateCaregiverProfileCommand(req.FullName), ct);
        return result.ToActionResult(this, value => value.Created
            ? Created("/api/v1/caregivers/me/profile", value.Profile)
            : Ok(value.Profile));
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
        var result = await sender.Send(new SubmitCaregiverKycCommand(req.CccdNumber,
            req.CccdFrontUrl, req.CccdBackUrl, req.CertificateUrls), ct);
        return result.ToActionResult(this);
    }

    /// <summary>
    /// Caregiver cập nhật thông tin hồ sơ cá nhân (bio, kỹ năng, khu vực phục vụ).
    /// Chỉ Caregiver của profile đó mới có quyền cập nhật (kiểm tra qua JWT).
    /// Không ảnh hưởng đến trạng thái KYC.
    /// </summary>
    /// <param name="req">Các trường cần cập nhật (FullName, Bio, YearsOfExperience, Skills, ServiceCity, ServiceDistrict, Gender, DateOfBirth).</param>
    /// <param name="ct">Token hủy tác vụ bất đồng bộ.</param>
    /// <returns>200 OK kèm thông tin profile sau khi cập nhật.</returns>
    [HttpPut("api/v1/caregivers/me/profile")]
    public async Task<IActionResult> UpdateMyProfile([FromBody] UpdateCaregiverProfileRequest req, CancellationToken ct)
    {
        var result = await sender.Send(new UpdateCaregiverProfileCommand(req.FullName,
            req.Bio, req.YearsOfExperience, req.Skills, req.ServiceCity,
            req.ServiceDistrict, req.Gender, req.DateOfBirth), ct);
        return result.ToActionResult(this);
    }

    /// <summary>
    /// Caregiver cập nhật trạng thái sẵn sàng nhận việc (ONLINE, OFFLINE, BUSY).
    /// </summary>
    [HttpPut("api/v1/caregivers/me/status")]
    public async Task<IActionResult> UpdateMyAvailabilityStatus(
        [FromBody] UpdateCaregiverStatusRequest req, CancellationToken ct)
    {
        var result = await sender.Send(
            new UpdateCaregiverAvailabilityStatusCommand(req.Status), ct);
        return result.ToActionResult(this);
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
        if (!string.IsNullOrWhiteSpace(status) && !string.Equals(status, "ALL", StringComparison.OrdinalIgnoreCase))
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
        var result = await sender.Send(new ApproveCaregiverKycCommand(id), ct);
        return result.ToActionResult(this);
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
        var result = await sender.Send(new RejectCaregiverKycCommand(id, req?.Reason), ct);
        return result.ToActionResult(this);
    }

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
    string? Skills = null,
    string? ServiceCity = null, string? ServiceDistrict = null,
    string? Gender = null, DateOnly? DateOfBirth = null);
