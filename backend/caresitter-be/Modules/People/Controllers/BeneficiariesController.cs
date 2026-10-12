using System.Text.Json;
using CareSitter.Modules.People.Application;
using CareSitter.Modules.People.Application.Commands.CreateBeneficiary;
using CareSitter.Modules.People.Application.Commands.DeleteBeneficiary;
using CareSitter.Modules.People.Application.Commands.UpdateBeneficiary;
using MediatR;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;

namespace CareSitter.Modules.People.Controllers;

/// <summary>
/// Quản lý hồ sơ người thân (người được chăm sóc) thuộc tài khoản khách hàng.
/// Sử dụng PostgreSQL Row-Level Security (RLS) để cách ly dữ liệu giữa các user.
/// </summary>
[ApiController]
[Authorize]
[Route("api/v1/beneficiaries")]
public sealed class BeneficiariesController : ControllerBase
{
    private readonly IMediator _mediator;

    public BeneficiariesController(IMediator mediator)
    {
        _mediator = mediator;
    }

    /// <summary>Lấy danh sách tất cả hồ sơ người thân của user, sắp xếp theo tên.</summary>
    [HttpGet]
    public async Task<IActionResult> List(CancellationToken ct)
    {
        var result = await _mediator.Send(new ListBeneficiariesQuery(), ct);
        return result.ToActionResult(this);
    }

    /// <summary>Xem chi tiết một hồ sơ người thân theo ID, chỉ trả về nếu thuộc user hiện tại.</summary>
    [HttpGet("{id:guid}")]
    public async Task<IActionResult> Get(Guid id, CancellationToken ct)
    {
        var result = await _mediator.Send(new GetBeneficiaryQuery(id), ct);
        return result.ToActionResult(this);
    }

    /// <summary>
    /// Tạo hồ sơ người thân mới. Kiểm tra hợp lệ giới tính, ngày sinh và địa chỉ trước khi lưu.
    /// </summary>
    [HttpPost]
    public async Task<IActionResult> Create([FromBody] BeneficiaryUpsertRequest request, CancellationToken ct)
    {
        var result = await _mediator.Send(ToCreateCommand(request), ct);
        return result.ToActionResult(this,
            beneficiary => Created($"/api/v1/beneficiaries/{beneficiary.Id}", beneficiary));
    }

    /// <summary>Cập nhật hồ sơ của owner. Trường tùy chọn bị bỏ qua được giữ nguyên; null tường minh sẽ xóa.</summary>
    [HttpPut("{id:guid}")]
    public async Task<IActionResult> Update(Guid id, [FromBody] BeneficiaryUpdateRequest request, CancellationToken ct)
    {
        var result = await _mediator.Send(ToUpdateCommand(id, request), ct);
        return result.ToActionResult(this);
    }

    /// <summary>Soft-delete hồ sơ người thân (gán DeletedAt, không xóa vật lý).</summary>
    [HttpDelete("{id:guid}")]
    public async Task<IActionResult> Delete(Guid id, CancellationToken ct)
    {
        var result = await _mediator.Send(new DeleteBeneficiaryCommand(id), ct);
        return result.ToActionResult(this, _ => NoContent());
    }

    private static CreateBeneficiaryCommand ToCreateCommand(BeneficiaryUpsertRequest request) =>
        new(request.FullName, request.DateOfBirth, request.Gender,
            request.RelationshipToCustomer, request.Phone, request.DefaultAddressId,
            request.MobilityNote, request.GeneralNote, request.HealthHistory,
            request.Allergies, request.ChronicConditions, request.CareInstructions,
            request.CareLevel, request.AvatarUrl, request.EmergencyContacts,
            request.Medications);

    private static UpdateBeneficiaryCommand ToUpdateCommand(
        Guid id, BeneficiaryUpdateRequest request) =>
        new(id, request.FullName, request.DateOfBirth, request.Gender,
            request.RelationshipToCustomer, request.Phone, request.DefaultAddressId,
            request.MobilityNote, request.GeneralNote, request.HealthHistory,
            request.Allergies, request.ChronicConditions, request.CareInstructions,
            request.CareLevel, request.AvatarUrl, request.EmergencyContacts,
            request.Medications, request.ProvidedFields);
}
