using CareSitter.Infrastructure.Security;
using CareSitter.Modules.Catalog.Application;
using CareSitter.Modules.Catalog.Application.Commands.CreateAddress;
using CareSitter.Modules.Catalog.Application.Commands.DeleteAddress;
using CareSitter.Modules.Catalog.Application.Commands.SetDefaultAddress;
using CareSitter.Modules.Catalog.Application.Commands.UpdateAddress;
using CareSitter.Modules.Catalog.Domain;
using CareSitter.Modules.Catalog.Infrastructure;
using MediatR;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace CareSitter.Modules.Catalog.Controllers;

/// <summary>
/// Quản lý sổ địa chỉ của khách hàng (nơi chăm sóc, nhà riêng, v.v.).
/// Mọi thao tác yêu cầu xác thực và chỉ đọc/sửa địa chỉ thuộc về user đó.
/// </summary>
[ApiController]
[Authorize]
[Route("api/v1/addresses")]
public sealed class AddressesController(
    CatalogDbContext db,
    ICurrentUser currentUser,
    IPlaceAutocompleteService places,
    ISender sender) : ControllerBase
{
    /// <summary>Gợi ý địa chỉ thật từ Geoapify. Chỉ gợi ý trong Việt Nam.</summary>
    [HttpGet("autocomplete")]
    [ProducesResponseType(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status503ServiceUnavailable)]
    public async Task<IActionResult> Autocomplete(
        [FromQuery] string input,
        [FromQuery] string? sessionToken,
        CancellationToken ct)
    {
        if (currentUser.UserId is null) return Unauthorized();
        try
        {
            var suggestions = await places.AutocompleteAsync(input, sessionToken, ct);
            return Ok(suggestions);
        }
        catch (InvalidOperationException ex)
        {
            return StatusCode(StatusCodes.Status503ServiceUnavailable, new { error = ex.Message });
        }
    }

    /// <summary>Resolve Place ID thành địa chỉ đã xác minh và tọa độ chuẩn.</summary>
    [HttpGet("places/{placeId}")]
    [ProducesResponseType(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    [ProducesResponseType(StatusCodes.Status503ServiceUnavailable)]
    public async Task<IActionResult> GetPlace(
        string placeId,
        [FromQuery] string? sessionToken,
        CancellationToken ct)
    {
        if (currentUser.UserId is null) return Unauthorized();
        try
        {
            var details = await places.GetDetailsAsync(placeId, sessionToken, ct);
            return details is null
                ? NotFound(new { error = "Dia chi khong hop le hoac khong thuoc Viet Nam." })
                : Ok(details);
        }
        catch (InvalidOperationException ex)
        {
            return StatusCode(StatusCodes.Status503ServiceUnavailable, new { error = ex.Message });
        }
    }

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

    /// <summary>Tạo địa chỉ mới cho user từ Geoapify Place ID đã xác minh.</summary>
    [HttpPost]
    [ProducesResponseType(StatusCodes.Status201Created)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    public async Task<IActionResult> Create([FromBody] AddressUpsertRequest request, CancellationToken ct)
    {
        var result = await sender.Send(new CreateAddressCommand(request.PlaceId,
            request.SessionToken, request.Label, request.Note), ct);
        return result.ToActionResult(this,
            address => Created($"/api/v1/addresses/{address.Id}", address));
    }

    /// <summary>Cập nhật địa chỉ theo ID. Chỉ owner mới sửa được.</summary>
    [HttpPut("{id:guid}")]
    [ProducesResponseType(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> Update(Guid id, [FromBody] AddressUpsertRequest request, CancellationToken ct)
    {
        var result = await sender.Send(new UpdateAddressCommand(id, request.PlaceId,
            request.SessionToken, request.Label, request.Note), ct);
        return result.ToActionResult(this);
    }

    /// <summary>Xóa địa chỉ. Trả về 409 Conflict nếu địa chỉ đang được liên kết với booking/beneficiary.</summary>
    [HttpDelete("{id:guid}")]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    [ProducesResponseType(StatusCodes.Status409Conflict)]
    public async Task<IActionResult> Delete(Guid id, CancellationToken ct)
    {
        var result = await sender.Send(new DeleteAddressCommand(id), ct);
        return result.ToActionResult(this, _ => NoContent());
    }

    /// <summary>
    /// Xác nhận địa chỉ này thuộc user và đánh dấu để set làm default.
    /// Dùng kèm với PUT /api/v1/profile/default-address/{id} ở Identity module.
    /// Endpoint này chỉ validate ownership, trả về 200 nếu hợp lệ.
    /// </summary>
    [HttpPut("{id:guid}/default")]
    [ProducesResponseType(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> SetDefault(Guid id, CancellationToken ct)
    {
        var result = await sender.Send(new SetDefaultAddressCommand(id), ct);
        return result.ToActionResult(this);
    }

    private static AddressResponse ToResponse(Address x) => new(x.Id, x.FullAddress,
        x.Location.Y, x.Location.X, x.Label, x.Ward, x.District, x.City, x.Country,
        x.PlaceId, x.Provider, x.VerifiedAt, x.IsVerified, x.Note);
}

public sealed record AddressUpsertRequest(
    string PlaceId,
    string? SessionToken,
    string? Label,
    string? Note = null);
