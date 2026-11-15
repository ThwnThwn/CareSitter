using CareSitter.Modules.Payments.Application.Payouts;
using CareSitter.SharedKernel.Results;
using Microsoft.AspNetCore.Mvc;

namespace CareSitter.Modules.Payments.Controllers;

internal static class PaymentResultExtensions
{
    public static IActionResult ToActionResult<T>(
        this Result<T> result,
        ControllerBase controller,
        Func<T, IActionResult>? onSuccess = null)
    {
        if (result.IsSuccess)
            return onSuccess?.Invoke(result.Value) ?? controller.Ok(result.Value);

        var error = result.Error;
        if (error.Code == PayoutErrors.UnauthenticatedCode)
            return controller.Unauthorized();
        if (error.Code == PayoutErrors.NotFoundCode)
            return controller.NotFound();
        if (error.Code is PayoutErrors.WalletNotFoundCode or PayoutErrors.InsufficientBalanceCode)
            return controller.BadRequest(new { error = error.Message });

        return error.Type switch
        {
            ErrorType.NotFound => controller.NotFound(new ProblemDetails
                { Title = error.Code, Detail = error.Message }),
            ErrorType.Conflict => controller.Conflict(new ProblemDetails
                { Title = error.Code, Detail = error.Message }),
            ErrorType.Forbidden => controller.Forbid(),
            ErrorType.Unauthorized => controller.Unauthorized(new ProblemDetails
                { Title = error.Code, Detail = error.Message }),
            _ => controller.BadRequest(new ProblemDetails
                { Title = error.Code, Detail = error.Message })
        };
    }
}
