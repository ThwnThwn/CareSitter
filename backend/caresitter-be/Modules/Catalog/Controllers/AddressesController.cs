using CareSitter.Infrastructure.Security;
using CareSitter.Modules.Catalog.Domain;
using CareSitter.Modules.Catalog.Infrastructure;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using NetTopologySuite.Geometries;

namespace CareSitter.Modules.Catalog.Controllers;

/// <summary>
/// Quản lý sổ địa chỉ của khách hàng (nơi chăm sóc, nhà riêng, v.v.).
/// Mọi thao tác yêu cầu xác thực và chỉ đọc/sửa địa chỉ thuộc về user đó.
/// </summary>
[ApiController]
[Authorize]
[Route("api/v1/addresses")]
public sealed class AddressesController(CatalogDbContext db, ICurrentUser currentUser) : ControllerBase
{
    /// <summary>Lấy danh sách địa chỉ của user hiện tại, sắp xếp theo ngày cập nhật gần nhất.</summary>
    [HttpGet]
    [ProducesResponseType(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    public async Task<IActionResult> List(CancellationToken ct)
    {
        if (currentUser.UserId is not { } userId) return Unauthorized();
        var items = await db.Addresses.AsNoTracking().Where(x => x.OwnerUserId == userId)
            .OrderByDescending(x => x.UpdatedAt).ToListAsync(ct);
        return Ok(items.Select(ToResponse));
    }

    /// <summary>Xem chi tiết một địa chỉ theo ID. Chỉ trả về nếu thuộc user đó.</summary>
    [HttpGet("{id:guid}")]
    [ProducesResponseType(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> Get(Guid id, CancellationToken ct)
    {
        if (currentUser.UserId is not { } userId) return Unauthorized();
        var entity = await db.Addresses.AsNoTracking()
            .SingleOrDefaultAsync(x => x.Id == id && x.OwnerUserId == userId, ct);
        return entity is null ? NotFound() : Ok(ToResponse(entity));
    }

    /// <summary>Tạo địa chỉ mới cho user. Toạ độ (Lat/Lng) được chuẩn hóa sang điểm PostGIS SRID 4326.</summary>
    [HttpPost]
    [ProducesResponseType(StatusCodes.Status201Created)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    public async Task<IActionResult> Create([FromBody] AddressUpsertRequest request, CancellationToken ct)
    {
        if (currentUser.UserId is not { } userId) return Unauthorized();
        var point = CreatePoint(request.Latitude, request.Longitude);
        if (point is null) return BadRequest(new { error = "Toa do khong hop le." });
        var created = Address.Create(request.FullAddress, point, userId, request.Label,
            request.Ward, request.District, request.City, request.Country, request.Note);
        if (created.IsFailure) return BadRequest(new { error = created.Error.Message });
        db.Addresses.Add(created.Value);
        await db.SaveChangesAsync(ct);
        return Created($"/api/v1/addresses/{created.Value.Id}", ToResponse(created.Value));
    }

    /// <summary>Cập nhật địa chỉ theo ID. Chỉ owner mới sửa được.</summary>
    [HttpPut("{id:guid}")]
    [ProducesResponseType(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> Update(Guid id, [FromBody] AddressUpsertRequest request, CancellationToken ct)
    {
        if (currentUser.UserId is not { } userId) return Unauthorized();
        var entity = await db.Addresses.SingleOrDefaultAsync(x =>
            x.Id == id && x.OwnerUserId == userId, ct);
        if (entity is null) return NotFound();
        var point = CreatePoint(request.Latitude, request.Longitude);
        if (point is null) return BadRequest(new { error = "Toa do khong hop le." });
        var result = entity.Update(request.FullAddress, point, request.Label, request.Ward,
            request.District, request.City, request.Country, request.Note);
        if (result.IsFailure) return BadRequest(new { error = result.Error.Message });
        await db.SaveChangesAsync(ct);
        return Ok(ToResponse(entity));
    }

    /// <summary>Xóa địa chỉ. Trả về 409 Conflict nếu địa chỉ đang được liên kết với booking/beneficiary.</summary>
    [HttpDelete("{id:guid}")]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    [ProducesResponseType(StatusCodes.Status409Conflict)]
    public async Task<IActionResult> Delete(Guid id, CancellationToken ct)
    {
        if (currentUser.UserId is not { } userId) return Unauthorized();
        var entity = await db.Addresses.SingleOrDefaultAsync(x =>
            x.Id == id && x.OwnerUserId == userId, ct);
        if (entity is null) return NotFound();
        db.Addresses.Remove(entity);
        try
        {
            await db.SaveChangesAsync(ct);
            return NoContent();
        }
        catch (DbUpdateException)
        {
            return Conflict(new { error = "Dia chi dang duoc su dung va khong the xoa." });
        }
    }

    private static Point? CreatePoint(double latitude, double longitude)
    {
        if (latitude is < -90 or > 90 || longitude is < -180 or > 180) return null;
        return new Point(longitude, latitude) { SRID = 4326 };
    }

    private static AddressResponse ToResponse(Address x) => new(x.Id, x.FullAddress,
        x.Location.Y, x.Location.X, x.Label, x.Ward, x.District, x.City, x.Country, x.Note);
}

public sealed record AddressUpsertRequest(string FullAddress, double Latitude,
    double Longitude, string? Label, string? Ward, string? District, string? City,
    string Country = "Vietnam", string? Note = null);

public sealed record AddressResponse(Guid Id, string FullAddress, double Latitude,
    double Longitude, string? Label, string? Ward, string? District, string? City,
    string Country, string? Note);
