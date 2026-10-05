using CareSitter.Modules.Identity.Application;
using MediatR;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;

namespace CareSitter.Modules.Identity.Controllers;

[ApiController]
[Route("api/v1/auth/devices")]
[Authorize]
public sealed class DeviceController : ControllerBase
{
    private readonly IMediator _mediator;

    public DeviceController(IMediator mediator)
    {
        _mediator = mediator;
    }

    [HttpPost]
    [ProducesResponseType(typeof(DeviceResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(typeof(DeviceResponse), StatusCodes.Status201Created)]
    public async Task<IActionResult> RegisterDevice(
        [FromBody] RegisterDeviceRequest request, CancellationToken ct)
    {
        var result = await _mediator.Send(new RegisterDeviceCommand(
            request.Platform, request.PushToken, request.DeviceName), ct);
        return result.ToActionResult(this, outcome => outcome.Created
            ? Created($"/api/v1/auth/devices/{outcome.Device.Id}", outcome.Device)
            : Ok(outcome.Device));
    }

    [HttpGet]
    public async Task<IActionResult> ListMyDevices(CancellationToken ct)
    {
        var result = await _mediator.Send(new ListMyDevicesQuery(), ct);
        return result.ToActionResult(this);
    }

    [HttpDelete("{id:guid}")]
    public async Task<IActionResult> DeleteDevice(Guid id, CancellationToken ct)
    {
        var result = await _mediator.Send(new DeleteDeviceCommand(id), ct);
        return result.ToActionResult(this, NoContent);
    }
}
