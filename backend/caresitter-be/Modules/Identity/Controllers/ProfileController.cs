using CareSitter.Modules.Identity.Application;
using CareSitter.Modules.Identity.Application.UpdateProfile;
using MediatR;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;

namespace CareSitter.Modules.Identity.Controllers;

[ApiController]
[Authorize]
[Route("api/v1/profile")]
public sealed class ProfileController(ISender sender) : ControllerBase
{
    [HttpGet]
    [ProducesResponseType(typeof(ProfileResponse), StatusCodes.Status200OK)]
    public async Task<IActionResult> Get(CancellationToken ct)
    {
        var result = await sender.Send(new GetProfileQuery(), ct);
        return result.ToActionResult(this);
    }

    [HttpPut]
    [ProducesResponseType(typeof(ProfileResponse), StatusCodes.Status200OK)]
    public async Task<IActionResult> Update([FromBody] UpdateProfileCommand command, CancellationToken ct)
    {
        var result = await sender.Send(command, ct);
        return result.ToActionResult(this);
    }

    [HttpPost("avatar")]
    [RequestSizeLimit(5 * 1024 * 1024)]
    [ProducesResponseType(typeof(AvatarResponse), StatusCodes.Status200OK)]
    public async Task<IActionResult> UploadAvatar(IFormFile file, CancellationToken ct)
    {
        if (file is null)
            return BadRequest(new ProblemDetails { Title = "avatar.empty", Detail = "File không được rỗng." });

        await using var stream = file.OpenReadStream();
        var result = await sender.Send(new UploadAvatarCommand(
            stream, file.FileName, file.ContentType, file.Length), ct);
        return result.ToActionResult(this);
    }

    [HttpPut("default-address/{addressId:guid}")]
    public async Task<IActionResult> SetDefaultAddress(Guid addressId, CancellationToken ct)
    {
        var result = await sender.Send(new SetDefaultAddressCommand(addressId), ct);
        return result.ToActionResult(this, id => Ok(new { defaultAddressId = id }));
    }

    [HttpPut("password")]
    public async Task<IActionResult> ChangePassword(
        [FromBody] ChangePasswordRequest request, CancellationToken ct)
    {
        var result = await sender.Send(
            new ChangePasswordCommand(request.CurrentPassword, request.NewPassword), ct);
        return result.ToActionResult(this, message => Ok(new { message }));
    }

    [HttpGet("notification-preferences")]
    [ProducesResponseType(typeof(NotificationPrefs), StatusCodes.Status200OK)]
    public async Task<IActionResult> GetNotificationPrefs(CancellationToken ct)
    {
        var result = await sender.Send(new GetNotificationPrefsQuery(), ct);
        return result.ToActionResult(this);
    }

    [HttpPut("notification-preferences")]
    [ProducesResponseType(typeof(NotificationPrefs), StatusCodes.Status200OK)]
    public async Task<IActionResult> UpdateNotificationPrefs(
        [FromBody] NotificationPrefs request, CancellationToken ct)
    {
        var result = await sender.Send(new UpdateNotificationPrefsCommand(request), ct);
        return result.ToActionResult(this);
    }
}

public sealed record ChangePasswordRequest(string CurrentPassword, string NewPassword);
