using CareSitter.Modules.Support.Application.Commands;
using CareSitter.SharedKernel.Results;
using Microsoft.AspNetCore.Mvc;

namespace CareSitter.Modules.Support.Controllers;

public static class SupportResultExtensions
{
    private static readonly HashSet<string> LegacyBadRequestCodes =
    [
        SupportErrors.ReviewRequiredIdsCode,
        SupportErrors.ReviewCommentTooLongCode,
        SupportErrors.ReviewTagsTooLongCode,
        SupportErrors.ReviewCaregiverMismatchCode,
        SupportErrors.InvalidAttachmentsCode
    ];

    private static readonly HashSet<string> LegacyConflictCodes =
    [
        SupportErrors.DisputeAlreadyExistsCode,
        SupportErrors.ReviewBookingNotCompletedCode,
        SupportErrors.ReviewAlreadyExistsCode,
        SupportErrors.ReviewConcurrentDuplicateCode
    ];

    public static IActionResult ToActionResult<T>(this Result<T> result,
        ControllerBase controller, Func<T, IActionResult>? onSuccess = null)
    {
        if (result.IsSuccess)
            return onSuccess?.Invoke(result.Value) ?? controller.Ok(result.Value);

        var error = result.Error;
        if (error.Code == SupportErrors.UnauthenticatedCode)
            return controller.Unauthorized();
        if (error.Code == SupportErrors.NotFoundCode)
            return controller.NotFound();
        if (error.Code == SupportErrors.ReviewBookingNotFoundCode)
            return controller.NotFound(new { error = error.Message });
        if (LegacyBadRequestCodes.Contains(error.Code))
            return controller.BadRequest(new { error = error.Message });
        if (LegacyConflictCodes.Contains(error.Code))
            return controller.Conflict(new { error = error.Message });

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
