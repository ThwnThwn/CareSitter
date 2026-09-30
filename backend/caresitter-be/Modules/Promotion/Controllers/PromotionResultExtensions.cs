using CareSitter.SharedKernel.Results;
using Microsoft.AspNetCore.Mvc;

namespace CareSitter.Modules.Promotion.Controllers;

internal static class PromotionResultExtensions
{
    public static IActionResult ToActionResult<T>(this Result<T> result,
        ControllerBase controller)
    {
        if (result.IsSuccess) return controller.Ok(result.Value);
        var problem = new ProblemDetails
        {
            Title = result.Error.Code,
            Detail = result.Error.Message
        };
        return result.Error.Type switch
        {
            ErrorType.NotFound => controller.NotFound(problem),
            ErrorType.Conflict => controller.Conflict(problem),
            ErrorType.Unauthorized => controller.Unauthorized(problem),
            ErrorType.Forbidden => controller.Forbid(),
            _ => controller.BadRequest(problem)
        };
    }
}
