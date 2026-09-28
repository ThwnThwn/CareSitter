using CareSitter.SharedKernel.Results;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;

namespace CareSitter.Modules.Identity.Controllers;

internal static class IdentityResultExtensions
{
    internal static IActionResult ToActionResult<T>(this Result<T> result,
        ControllerBase controller, Func<T, IActionResult>? onSuccess = null)
    {
        if (result.IsSuccess)
            return onSuccess?.Invoke(result.Value) ?? controller.Ok(result.Value);
        return Failure(controller, result.Error);
    }

    internal static IActionResult ToActionResult(this Result result,
        ControllerBase controller, Func<IActionResult>? onSuccess = null)
    {
        if (result.IsSuccess) return onSuccess?.Invoke() ?? controller.NoContent();
        return Failure(controller, result.Error);
    }

    private static IActionResult Failure(ControllerBase controller, Error error)
    {
        var problem = new ProblemDetails { Title = error.Code, Detail = error.Message };
        return error.Type switch
        {
            ErrorType.Unauthorized => controller.Unauthorized(),
            ErrorType.Forbidden => controller.StatusCode(StatusCodes.Status403Forbidden, problem),
            ErrorType.NotFound => controller.NotFound(problem),
            ErrorType.Conflict => controller.Conflict(problem),
            ErrorType.Unavailable => controller.StatusCode(StatusCodes.Status503ServiceUnavailable, problem),
            _ => controller.BadRequest(problem)
        };
    }
}
