using CareSitter.Infrastructure.Security;
using CareSitter.Modules.People.Infrastructure;
using CareSitter.SharedKernel.Results;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

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

        var cccdEncrypted = encryption.Encrypt(req.CccdNumber);
        var cccdHash = encryption.Hmac(req.CccdNumber);

        var result = profile.SubmitKyc(cccdEncrypted, cccdHash);
        if (result.IsFailure) return Problem(result.Error);

        await db.SaveChangesAsync(ct);
        return Ok(new { kycStatus = profile.KycStatus, message = "Ho so KYC da duoc nop." });
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
            profile.Id, profile.FullName, profile.Bio, profile.YearsOfExperience,
            profile.HourlyRateExpected, profile.KycStatus, profile.AvailabilityStatus,
            profile.ServiceCity, profile.ServiceDistrict
        });
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
}

public sealed record SubmitKycRequest(string CccdNumber, string[]? CertificateUrls = null);
public sealed record RejectKycRequest(string? Reason);
public sealed record UpdateCaregiverProfileRequest(
    string? FullName = null, string? Bio = null, int? YearsOfExperience = null,
    long? HourlyRateExpected = null, string? Skills = null,
    string? ServiceCity = null, string? ServiceDistrict = null,
    string? Gender = null, DateOnly? DateOfBirth = null);
