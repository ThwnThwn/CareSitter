using System.Text.Json;
using CareSitter.Infrastructure.Security;
using CareSitter.Modules.People.Application;
using CareSitter.Modules.People.Application.Commands.CreateBeneficiary;
using CareSitter.Modules.People.Application.Commands.DeleteBeneficiary;
using CareSitter.Modules.People.Application.Commands.UpdateBeneficiary;
using CareSitter.Modules.People.Domain;
using CareSitter.Modules.People.Infrastructure;
using MediatR;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Storage;

namespace CareSitter.Modules.People.Controllers;

/// <summary>
/// Quản lý hồ sơ người thân (người được chăm sóc) thuộc tài khoản khách hàng.
/// Sử dụng PostgreSQL Row-Level Security (RLS) để cách ly dữ liệu giữa các user.
/// </summary>
[ApiController]
[Authorize]
[Route("api/v1/beneficiaries")]
public sealed class BeneficiariesController(
    PeopleDbContext db, ICurrentUser currentUser, ISender sender) : ControllerBase
{
    /// <summary>Lấy danh sách tất cả hồ sơ người thân của user, sắp xếp theo tên.</summary>
    [HttpGet]
    public async Task<IActionResult> List(CancellationToken ct)
    {
        if (currentUser.UserId is not { } userId) return Unauthorized();
        await using var tx = await BeginRls(userId, ct);
        var entities = await db.Beneficiaries.AsNoTracking()
            .Where(x => x.CustomerId == userId && x.DeletedAt == null)
            .OrderBy(x => x.FullName).ToListAsync(ct);
        return Ok(entities.Select(ToResponse));
    }

    /// <summary>Xem chi tiết một hồ sơ người thân theo ID, chỉ trả về nếu thuộc user hiện tại.</summary>
    [HttpGet("{id:guid}")]
    public async Task<IActionResult> Get(Guid id, CancellationToken ct)
    {
        if (currentUser.UserId is not { } userId) return Unauthorized();
        await using var tx = await BeginRls(userId, ct);
        var entity = await db.Beneficiaries.AsNoTracking().SingleOrDefaultAsync(x =>
            x.Id == id && x.CustomerId == userId && x.DeletedAt == null, ct);
        return entity is null ? NotFound() : Ok(ToResponse(entity));
    }

    /// <summary>
    /// Tạo hồ sơ người thân mới. Kiểm tra hợp lệ giới tính, ngày sinh và địa chỉ trước khi lưu.
    /// </summary>
    [HttpPost]
    public async Task<IActionResult> Create([FromBody] BeneficiaryUpsertRequest request, CancellationToken ct)
    {
        var result = await sender.Send(ToCreateCommand(request), ct);
        return result.ToActionResult(this,
            beneficiary => Created($"/api/v1/beneficiaries/{beneficiary.Id}", beneficiary));
    }

    /// <summary>Cập nhật thông tin hồ sơ người thân. Chỉ owner mới sửa được.</summary>
    [HttpPut("{id:guid}")]
    public async Task<IActionResult> Update(Guid id, [FromBody] BeneficiaryUpsertRequest request, CancellationToken ct)
    {
        var result = await sender.Send(ToUpdateCommand(id, request), ct);
        return result.ToActionResult(this);
    }

    /// <summary>Soft-delete hồ sơ người thân (gán DeletedAt, không xóa vật lý).</summary>
    [HttpDelete("{id:guid}")]
    public async Task<IActionResult> Delete(Guid id, CancellationToken ct)
    {
        var result = await sender.Send(new DeleteBeneficiaryCommand(id), ct);
        return result.ToActionResult(this, _ => NoContent());
    }

    // ── Helpers ──

    private async Task<IDbContextTransaction> BeginRls(Guid userId, CancellationToken ct)
    {
        var tx = await db.Database.BeginTransactionAsync(ct);
        await db.Database.ExecuteSqlInterpolatedAsync(
            $"SELECT set_config('app.current_user_id', {userId.ToString()}, true)", ct);
        return tx;
    }

    private static BeneficiaryResponse ToResponse(Beneficiary x) => new(x.Id, x.FullName,
        x.DateOfBirth, x.Gender, x.RelationshipToCustomer, x.Phone, x.DefaultAddressId,
        x.MobilityNote, x.GeneralNote, Json(x.HealthHistory), Json(x.Allergies),
        Json(x.ChronicConditions), x.CareInstructions, Json(x.EmergencyContacts), Json(x.Medications));

    private static JsonElement? Json(string? value) => string.IsNullOrWhiteSpace(value)
        ? null : JsonDocument.Parse(value).RootElement.Clone();

    private static CreateBeneficiaryCommand ToCreateCommand(BeneficiaryUpsertRequest request) =>
        new(request.FullName, request.DateOfBirth, request.Gender,
            request.RelationshipToCustomer, request.Phone, request.DefaultAddressId,
            request.MobilityNote, request.GeneralNote, request.HealthHistory,
            request.Allergies, request.ChronicConditions, request.CareInstructions,
            request.EmergencyContacts, request.Medications);

    private static UpdateBeneficiaryCommand ToUpdateCommand(
        Guid id, BeneficiaryUpsertRequest request) =>
        new(id, request.FullName, request.DateOfBirth, request.Gender,
            request.RelationshipToCustomer, request.Phone, request.DefaultAddressId,
            request.MobilityNote, request.GeneralNote, request.HealthHistory,
            request.Allergies, request.ChronicConditions, request.CareInstructions,
            request.EmergencyContacts, request.Medications);
}

public sealed record BeneficiaryUpsertRequest(string FullName, DateOnly? DateOfBirth,
    string? Gender, string? RelationshipToCustomer, string? Phone, Guid? DefaultAddressId,
    string? MobilityNote, string? GeneralNote, JsonElement? HealthHistory,
    JsonElement? Allergies, JsonElement? ChronicConditions, string? CareInstructions,
    JsonElement? EmergencyContacts, JsonElement? Medications);
