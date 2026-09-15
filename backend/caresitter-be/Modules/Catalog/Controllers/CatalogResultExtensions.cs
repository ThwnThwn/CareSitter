using CareSitter.Modules.Catalog.Application.Commands;
using CareSitter.SharedKernel.Results;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;

namespace CareSitter.Modules.Catalog.Controllers;

public static class CatalogResultExtensions
{
    private static readonly HashSet<string> LegacyAnonymousValidationCodes =
    [
        CatalogErrors.VerifiedPlaceRequiredCode,
        CatalogErrors.InvalidCoordinatesCode,
        "address.full_address",
        "address.location",
        "address.country",
        "address.invalid"
    ];

    public static IActionResult ToActionResult<T>(
        this Result<T> result,
        ControllerBase controller,
        Func<T, IActionResult>? onSuccess = null)
    {
        if (result.IsSuccess)
            return onSuccess?.Invoke(result.Value) ?? controller.Ok(result.Value);

        var error = result.Error;
        if (error.Code == CatalogErrors.UnauthenticatedCode)
            return controller.Unauthorized();
        if (error.Code == CatalogErrors.AddressNotFoundCode)
            return controller.NotFound();
        if (error.Code == CatalogErrors.PlaceServiceUnavailableCode)
            return controller.StatusCode(StatusCodes.Status503ServiceUnavailable,
                new { error = error.Message });
        if (LegacyAnonymousValidationCodes.Contains(error.Code))
            return controller.BadRequest(new { error = error.Message });
        if (error.Code == CatalogErrors.AddressInUseCode)
            return controller.Conflict(new { error = error.Message });

        var problem = new ProblemDetails { Title = error.Code, Detail = error.Message };
        return error.Type switch
        {
            ErrorType.NotFound => controller.NotFound(problem),
            ErrorType.Conflict => controller.Conflict(problem),
            ErrorType.Forbidden => controller.Forbid(),
            ErrorType.Unauthorized => controller.Unauthorized(problem),
            ErrorType.Unavailable => controller.StatusCode(
                StatusCodes.Status503ServiceUnavailable, problem),
            _ => controller.BadRequest(problem)
        };
    }
}
