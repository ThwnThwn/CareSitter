using CareSitter.Modules.People.Application.Commands;
using CareSitter.SharedKernel.Results;
using Microsoft.AspNetCore.Mvc;

namespace CareSitter.Modules.People.Controllers;

public static class PeopleResultExtensions
{
    private static readonly HashSet<string> LegacyAnonymousValidationCodes =
    [
        PeopleErrors.InvalidCccdCode,
        PeopleErrors.InvalidCccdImageUrlsCode,
        PeopleErrors.InvalidCertificateUrlsCode
    ];

    public static IActionResult ToActionResult<T>(this Result<T> result,
        ControllerBase controller, Func<T, IActionResult>? onSuccess = null)
    {
        if (result.IsSuccess)
            return onSuccess?.Invoke(result.Value) ?? controller.Ok(result.Value);

        var error = result.Error;
        if (error.Code == PeopleErrors.UnauthenticatedCode)
            return controller.Unauthorized();
        if (error.Code == PeopleErrors.NotFoundCode)
            return controller.NotFound();
        if (error.Code == PeopleErrors.CaregiverProfileNotFoundCode)
            return controller.NotFound(new { error = error.Message });
        if (LegacyAnonymousValidationCodes.Contains(error.Code))
            return controller.BadRequest(new { error = error.Message });

        var problem = new ProblemDetails { Title = error.Code, Detail = error.Message };
        return error.Type switch
        {
            ErrorType.NotFound => controller.NotFound(problem),
            ErrorType.Conflict => controller.Conflict(problem),
            ErrorType.Forbidden => controller.Forbid(),
            ErrorType.Unauthorized => controller.Unauthorized(problem),
            _ => controller.BadRequest(problem)
        };
    }
}
