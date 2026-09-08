using CareSitter.Modules.Identity.Application.UpdateProfile;
using CareSitter.Modules.Identity.Infrastructure;
using CareSitter.Infrastructure.Security;
using CareSitter.SharedKernel.Results;
using MediatR;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace CareSitter.Modules.Identity.Controllers;

[ApiController]
[Authorize]
[Route("api/v1/profile")]
public sealed class ProfileController(
    ISender sender,
    IdentityDbContext db,
    ICurrentUser currentUser) : ControllerBase
{
    [HttpGet]
    [ProducesResponseType(typeof(ProfileResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status404NotFound)]
    public async Task<IActionResult> Get(CancellationToken ct)
    {
        if (currentUser.UserId is not { } userId)
            return Unauthorized();

        var profile = await db.Users.AsNoTracking()
            .Where(x => x.Id == userId && x.DeletedAt == null)
            .Select(x => new ProfileResponse(x.Id, x.Phone, x.Email, x.FullName!,
                x.DisplayName!, x.DateOfBirth, x.Gender, x.AvatarMediaId,
                x.DefaultAddressId, x.Roles))
            .SingleOrDefaultAsync(ct);

        return profile is null
            ? NotFound(Problem(Error.NotFound("profile.user_not_found", "Khong tim thay tai khoan nguoi dung.")))
            : Ok(profile);
    }

    [HttpPut]
    [ProducesResponseType(typeof(ProfileResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status400BadRequest)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status404NotFound)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status409Conflict)]
    public async Task<IActionResult> Update([FromBody] UpdateProfileCommand command, CancellationToken ct)
    {
        var result = await sender.Send(command, ct);
        return result.IsSuccess ? Ok(result.Value) : HandleFailure(result.Error);
    }

    private IActionResult HandleFailure(Error error) => error.Type switch
    {
        ErrorType.Validation => BadRequest(Problem(error)),
        ErrorType.NotFound => NotFound(Problem(error)),
        ErrorType.Conflict => Conflict(Problem(error)),
        ErrorType.Forbidden => Forbid(),
        _ => BadRequest(Problem(error))
    };

    private static ProblemDetails Problem(Error error) => new() { Title = error.Code, Detail = error.Message };
}
