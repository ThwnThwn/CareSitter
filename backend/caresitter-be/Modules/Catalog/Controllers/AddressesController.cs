using CareSitter.Modules.Catalog.Application;
using CareSitter.Modules.Catalog.Application.Commands.CreateAddress;
using CareSitter.Modules.Catalog.Application.Commands.DeleteAddress;
using CareSitter.Modules.Catalog.Application.Commands.SetDefaultAddress;
using CareSitter.Modules.Catalog.Application.Commands.UpdateAddress;
using MediatR;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;

namespace CareSitter.Modules.Catalog.Controllers;

/// <summary>
/// Quản lý sổ địa chỉ của khách hàng (nơi chăm sóc, nhà riêng, v.v.).
/// Mọi thao tác yêu cầu xác thực và chỉ đọc/sửa địa chỉ thuộc về user đó.
/// </summary>
[ApiController]
[Authorize]
[Route("api/v1/addresses")]
public sealed class AddressesController : ControllerBase
{
    private readonly IMediator _mediator;

    public AddressesController(IMediator mediator)
    {
        _mediator = mediator;
    }

    /// <summary>Gợi ý địa chỉ thật từ Geoapify. Chỉ gợi ý trong Việt Nam.</summary>
    [HttpGet("autocomplete")]
    [ProducesResponseType(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status503ServiceUnavailable)]
    public async Task<IActionResult> Autocomplete(
        [FromQuery] string input,
        [FromQuery] string? sessionToken,
        CancellationToken ct)
    {
        var result = await _mediator.Send(new AutocompletePlacesQuery(input, sessionToken), ct);
        return result.ToActionResult(this);
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
        var result = await _mediator.Send(new GetPlaceDetailsQuery(placeId, sessionToken), ct);
        return result.ToActionResult(this);
    }

    /// <summary>Lấy danh sách địa chỉ của user hiện tại, sắp xếp theo ngày cập nhật gần nhất.</summary>
    [HttpGet]
    [ProducesResponseType(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    public async Task<IActionResult> List(CancellationToken ct)
    {
        var result = await _mediator.Send(new ListOwnedAddressesQuery(), ct);
        return result.ToActionResult(this);
    }

    /// <summary>Xem chi tiết một địa chỉ theo ID. Chỉ trả về nếu thuộc user đó.</summary>
    [HttpGet("{id:guid}")]
    [ProducesResponseType(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> Get(Guid id, CancellationToken ct)
    {
        var result = await _mediator.Send(new GetOwnedAddressQuery(id), ct);
        return result.ToActionResult(this);
    }

    /// <summary>Tạo địa chỉ mới cho user từ Geoapify Place ID đã xác minh.</summary>
    [HttpPost]
    [ProducesResponseType(StatusCodes.Status201Created)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    public async Task<IActionResult> Create([FromBody] AddressUpsertRequest request, CancellationToken ct)
    {
        var result = await _mediator.Send(new CreateAddressCommand(request.PlaceId,
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
        var result = await _mediator.Send(new UpdateAddressCommand(id, request.PlaceId,
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
        var result = await _mediator.Send(new DeleteAddressCommand(id), ct);
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
        var result = await _mediator.Send(new SetDefaultAddressCommand(id), ct);
        return result.ToActionResult(this);
    }

}
