using System.Text.Json;
using CareSitter.Contracts.Services;
using CareSitter.Infrastructure.Security;
using CareSitter.Modules.People.Domain;
using CareSitter.Modules.People.Infrastructure;
using CareSitter.SharedKernel.Results;
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
    PeopleDbContext db, ICurrentUser currentUser, ICatalogLookupService catalog) : ControllerBase
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
        if (currentUser.UserId is not { } userId) return Unauthorized();
        var validation = await ValidateRequest(request, userId, ct);
        if (validation.IsFailure) return Failure(validation.Error);

        await using var tx = await BeginRls(userId, ct);
        var created = Beneficiary.Create(userId, request.FullName);
        if (created.IsFailure) return Failure(created.Error);
        var updated = ApplyRequest(created.Value, request);
        if (updated.IsFailure) return Failure(updated.Error);

        db.Beneficiaries.Add(created.Value);
        await db.SaveChangesAsync(ct);
        await tx.CommitAsync(ct);
        return Created($"/api/v1/beneficiaries/{created.Value.Id}", ToResponse(created.Value));
    }

    /// <summary>Cập nhật thông tin hồ sơ người thân. Chỉ owner mới sửa được.</summary>
    [HttpPut("{id:guid}")]
    public async Task<IActionResult> Update(Guid id, [FromBody] BeneficiaryUpsertRequest request, CancellationToken ct)
    {
        if (currentUser.UserId is not { } userId) return Unauthorized();
        var validation = await ValidateRequest(request, userId, ct);
        if (validation.IsFailure) return Failure(validation.Error);

        await using var tx = await BeginRls(userId, ct);
        var entity = await db.Beneficiaries.SingleOrDefaultAsync(x =>
            x.Id == id && x.CustomerId == userId && x.DeletedAt == null, ct);
        if (entity is null) return NotFound();
        var result = ApplyRequest(entity, request);
        if (result.IsFailure) return Failure(result.Error);
        await db.SaveChangesAsync(ct);
        await tx.CommitAsync(ct);
        return Ok(ToResponse(entity));
    }

    /// <summary>Soft-delete hồ sơ người thân (gán DeletedAt, không xóa vật lý).</summary>
    [HttpDelete("{id:guid}")]
    public async Task<IActionResult> Delete(Guid id, CancellationToken ct)
    {
        if (currentUser.UserId is not { } userId) return Unauthorized();
        await using var tx = await BeginRls(userId, ct);
        var entity = await db.Beneficiaries.SingleOrDefaultAsync(x =>
            x.Id == id && x.CustomerId == userId && x.DeletedAt == null, ct);
        if (entity is null) return NotFound();
        entity.Delete(DateTimeOffset.UtcNow);
        await db.SaveChangesAsync(ct);
        await tx.CommitAsync(ct);
        return NoContent();
    }

    // ── Helpers ──

    private async Task<IDbContextTransaction> BeginRls(Guid userId, CancellationToken ct)
    {
        var tx = await db.Database.BeginTransactionAsync(ct);
        await db.Database.ExecuteSqlInterpolatedAsync(
            $"SELECT set_config('app.current_user_id', {userId.ToString()}, true)", ct);
        return tx;
    }

    private static Result ApplyRequest(Beneficiary entity, BeneficiaryUpsertRequest request) =>
        entity.Update(request.FullName, request.DateOfBirth, NormalizeGender(request.Gender),
            request.RelationshipToCustomer, request.Phone, request.DefaultAddressId,
            request.MobilityNote, request.GeneralNote, Raw(request.HealthHistory),
            Raw(request.Allergies), Raw(request.ChronicConditions), request.CareInstructions,
            Raw(request.EmergencyContacts), Raw(request.Medications));

    private async Task<Result> ValidateRequest(BeneficiaryUpsertRequest request,
        Guid userId, CancellationToken ct)
    {
        if (NormalizeGender(request.Gender) == string.Empty)
            return Error.Validation("beneficiary.gender", "Giới tính không hợp lệ.");
        if (request.DateOfBirth > DateOnly.FromDateTime(DateTime.UtcNow))
            return Error.Validation("beneficiary.date_of_birth", "Ngày sinh không được ở tương lai.");
        if (request.DefaultAddressId is not { } addressId)
            return Error.Validation("beneficiary.address_required",
                "Vui lòng chọn địa chỉ đã xác minh cho người được chăm sóc.");
        if (!await catalog.AddressBelongsToAsync(addressId, userId, ct))
            return Error.Validation("beneficiary.address", "Địa chỉ không tồn tại hoặc không thuộc người dùng.");
        if (!await catalog.AddressIsVerifiedForBookingAsync(addressId, userId, ct))
            return Error.Validation("beneficiary.address_unverified",
                "Vui lòng chọn địa chỉ từ danh sách gợi ý trước khi lưu.");
        return Result.Success();
    }

    private static BeneficiaryResponse ToResponse(Beneficiary x) => new(x.Id, x.FullName,
        x.DateOfBirth, x.Gender, x.RelationshipToCustomer, x.Phone, x.DefaultAddressId,
        x.MobilityNote, x.GeneralNote, Json(x.HealthHistory), Json(x.Allergies),
        Json(x.ChronicConditions), x.CareInstructions, Json(x.EmergencyContacts), Json(x.Medications));

    private static JsonElement? Json(string? value) => string.IsNullOrWhiteSpace(value)
        ? null : JsonDocument.Parse(value).RootElement.Clone();

    private static string? NormalizeGender(string? value)
    {
        if (string.IsNullOrWhiteSpace(value)) return null;
        var gender = value.Trim().ToUpperInvariant();
        return gender is "MALE" or "FEMALE" or "OTHER" or "UNSPECIFIED" ? gender : string.Empty;
    }

    private IActionResult Failure(Error error) => error.Type switch
    {
        ErrorType.Conflict => Conflict(new ProblemDetails { Title = error.Code, Detail = error.Message }),
        _ => BadRequest(new ProblemDetails { Title = error.Code, Detail = error.Message })
    };

    private static string? Raw(JsonElement? value) => value?.GetRawText();
}

public sealed record BeneficiaryUpsertRequest(string FullName, DateOnly? DateOfBirth,
    string? Gender, string? RelationshipToCustomer, string? Phone, Guid? DefaultAddressId,
    string? MobilityNote, string? GeneralNote, JsonElement? HealthHistory,
    JsonElement? Allergies, JsonElement? ChronicConditions, string? CareInstructions,
    JsonElement? EmergencyContacts, JsonElement? Medications);

public sealed record BeneficiaryResponse(Guid Id, string FullName, DateOnly? DateOfBirth,
    string? Gender, string? RelationshipToCustomer, string? Phone, Guid? DefaultAddressId,
    string? MobilityNote, string? GeneralNote, JsonElement? HealthHistory,
    JsonElement? Allergies, JsonElement? ChronicConditions, string? CareInstructions,
    JsonElement? EmergencyContacts, JsonElement? Medications);
