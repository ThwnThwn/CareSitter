using CareSitter.Modules.People.Application;
using CareSitter.Modules.People.Application.Commands.ApproveCaregiverKyc;
using CareSitter.Modules.People.Application.Commands.CreateCaregiverProfile;
using CareSitter.Modules.People.Application.Commands.RejectCaregiverKyc;
using CareSitter.Modules.People.Application.Commands.SubmitCaregiverKyc;
using CareSitter.Modules.People.Application.Commands.UpdateCaregiverAvailabilityStatus;
using CareSitter.Modules.People.Application.Commands.UpdateCaregiverProfile;
using MediatR;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;

namespace CareSitter.Modules.People.Controllers;

/// <summary>
/// Quản lý hồ sơ (KYC) và thông tin cá nhân của Caregiver.
/// </summary>
[ApiController]
[Authorize]
[ResponseCache(NoStore = true, Location = ResponseCacheLocation.None)]
public sealed class CaregiverKycController : ControllerBase
{
    private readonly IMediator _mediator;

    public CaregiverKycController(IMediator mediator)
    {
        _mediator = mediator;
    }

    /// <summary>
    /// Tạo hồ sơ caregiver cho tài khoản CAREGIVER hiện tại.
    /// Endpoint idempotent để app có thể tự phục hồi tài khoản cũ còn thiếu profile.
    /// </summary>
    [HttpPost("api/v1/caregivers/me/profile")]
    [Authorize(Roles = "CAREGIVER")]
    public async Task<IActionResult> CreateMyProfile(
        [FromBody] CreateCaregiverProfileRequest req, CancellationToken ct)
    {
        var result = await _mediator.Send(new CreateCaregiverProfileCommand(req.FullName), ct);
        return result.ToActionResult(this, value => value.Created
            ? Created("/api/v1/caregivers/me/profile", value.Profile)
            : Ok(value.Profile));
    }

    /// <summary>
    /// Caregiver xem hồ sơ của chính mình theo JWT hiện tại.
    /// Dùng cho app caregiver để hiển thị đúng tên, rating, kỹ năng, khu vực và id profile.
    /// </summary>
    [HttpGet("api/v1/caregivers/me/profile")]
    [Authorize(Roles = "CAREGIVER")]
    public async Task<IActionResult> GetMyProfile(CancellationToken ct)
    {
        var result = await _mediator.Send(new GetMyCaregiverProfileQuery(), ct);
        return result.ToActionResult(this);
    }

    /// <summary>
    /// Caregiver nộp hồ sơ KYC (xác minh danh tính).
    /// Số CCCD được mã hóa AES (lưu vào DB) và tính HMAC (dùng kiểm tra trùng lặp) trước khi lưu.
    /// Sau khi nộp, trạng thái KYC chuyển sang PENDING — chờ Admin duyệt.
    /// </summary>
    /// <param name="req">CCCD và media IDs đã upload bằng tài khoản hiện tại; không nhận URL.</param>
    /// <param name="ct">Token hủy tác vụ bất đồng bộ.</param>
    /// <returns>200 OK kèm trạng thái KYC mới sau khi nộp.</returns>
    [HttpPost("api/v1/caregivers/me/kyc")]
    [Authorize(Roles = "CAREGIVER")]
    public async Task<IActionResult> SubmitKyc([FromBody] SubmitKycRequest req, CancellationToken ct)
    {
        var result = await _mediator.Send(new SubmitCaregiverKycCommand(req.CccdNumber,
            req.CccdFrontMediaId, req.CccdBackMediaId, req.CertificateMediaIds), ct);
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
    [Authorize(Roles = "CAREGIVER")]
    public async Task<IActionResult> UpdateMyProfile([FromBody] UpdateCaregiverProfileRequest req, CancellationToken ct)
    {
        var result = await _mediator.Send(new UpdateCaregiverProfileCommand(req.FullName,
            req.Bio, req.YearsOfExperience, req.Skills, req.ServiceCity,
            req.ServiceDistrict, req.Gender, req.DateOfBirth), ct);
        return result.ToActionResult(this);
    }

    /// <summary>
    /// Caregiver cập nhật trạng thái sẵn sàng nhận việc (ONLINE, OFFLINE, BUSY).
    /// </summary>
    [HttpPut("api/v1/caregivers/me/status")]
    [Authorize(Roles = "CAREGIVER")]
    public async Task<IActionResult> UpdateMyAvailabilityStatus(
        [FromBody] UpdateCaregiverStatusRequest req, CancellationToken ct)
    {
        var result = await _mediator.Send(
            new UpdateCaregiverAvailabilityStatusCommand(req.Status), ct);
        return result.ToActionResult(this);
    }

    /// <summary>Admin xem hàng đợi KYC cùng tài liệu đã nộp.</summary>
    [HttpGet("api/v1/caregivers/kyc")]
    [Authorize(Roles = "ADMIN")]
    public async Task<IActionResult> ListKyc(
        string? status = "PENDING", int page = 1, int pageSize = 20,
        CancellationToken ct = default)
    {
        var result = await _mediator.Send(new ListCaregiverKycQuery(status, page, pageSize), ct);
        return result.ToActionResult(this);
    }

    /// <summary>Admin xem chi tiết một hồ sơ KYC trước khi duyệt.</summary>
    [HttpGet("api/v1/caregivers/{id:guid}/kyc")]
    [Authorize(Roles = "ADMIN")]
    public async Task<IActionResult> GetKyc(Guid id, CancellationToken ct)
    {
        var result = await _mediator.Send(new GetCaregiverKycQuery(id), ct);
        return result.ToActionResult(this);
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
    [Authorize(Roles = "ADMIN")]
    public async Task<IActionResult> ApproveKyc(Guid id, CancellationToken ct)
    {
        var result = await _mediator.Send(new ApproveCaregiverKycCommand(id), ct);
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
    [Authorize(Roles = "ADMIN")]
    public async Task<IActionResult> RejectKyc(Guid id, [FromBody] RejectKycRequest? req, CancellationToken ct)
    {
        var result = await _mediator.Send(new RejectCaregiverKycCommand(id, req?.Reason), ct);
        return result.ToActionResult(this);
    }

}
