using CareSitter.Modules.Booking.Application.Commands;
using CareSitter.SharedKernel.Results;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;

namespace CareSitter.Modules.Booking.Controllers;

public static class BookingResultExtensions
{
    private static readonly HashSet<string> LegacyValidationCodes =
    [
        BookingErrors.ScheduleMustBeFutureCode,
        BookingErrors.DeclineReasonTooLongCode,
        BookingErrors.CaregiverMissingCode,
        BookingErrors.InvalidGpsCode,
        BookingErrors.InvalidGpsAccuracyCode,
        BookingErrors.AddressLocationMissingCode,
        BookingErrors.SelfieRequiredCode,
        BookingErrors.SelfieTooLargeCode,
        BookingErrors.SelfieInvalidTypeCode,
        BookingErrors.InvalidStatusCode
    ];

    private static readonly HashSet<string> LegacyConflictCodes =
    [
        BookingErrors.CaregiverScheduleConflictCode,
        BookingErrors.CaregiverNewScheduleConflictCode,
        BookingErrors.CaregiverNotSuggestedCode,
        BookingErrors.OfferNotValidCode,
        BookingErrors.CaregiverNotEligibleCode,
        BookingErrors.AlreadyAcceptedCode,
        BookingErrors.NotAwaitingAcceptanceCode,
        BookingErrors.NotOpenForDeclineCode,
        BookingErrors.SelfieInvalidStateCode,
        BookingErrors.PendingTasksCode,
        BookingErrors.CompleteInvalidStateCode,
        BookingErrors.OpenDisputeCode
    ];

    public static IActionResult ToActionResult<T>(
        this Result<T> result,
        ControllerBase controller,
        Func<T, IActionResult>? onSuccess = null)
    {
        if (result.IsSuccess)
            return onSuccess?.Invoke(result.Value) ?? controller.Ok(result.Value);

        return ToFailureActionResult(result.Error, controller);
    }

    public static IActionResult ToActionResult(
        this Result result,
        ControllerBase controller,
        Func<IActionResult>? onSuccess = null)
    {
        if (result.IsSuccess)
            return onSuccess?.Invoke() ?? controller.NoContent();
        return ToFailureActionResult(result.Error, controller);
    }

    private static IActionResult ToFailureActionResult(Error error, ControllerBase controller)
    {
        if (error.Code == BookingErrors.UnauthenticatedCode)
            return controller.Unauthorized();
        if (error.Code == BookingErrors.NotFoundCode)
            return controller.NotFound();
        if (LegacyValidationCodes.Contains(error.Code))
            return controller.BadRequest(new { error = error.Message });
        if (LegacyConflictCodes.Contains(error.Code))
            return controller.Conflict(new { error = error.Message });
        if (error.Code == BookingErrors.CaregiverSlotHeldCode)
            return controller.Conflict(new
            {
                error = error.Message,
                code = "CAREGIVER_TIME_SLOT_HELD"
            });
        if (error.Code == BookingErrors.GpsTrackingDisabledCode)
            return controller.StatusCode(StatusCodes.Status410Gone, new { error = error.Message });
        if (error.Code == "booking.chat.purged")
            return controller.StatusCode(StatusCodes.Status410Gone, new ProblemDetails
                { Title = error.Code, Detail = error.Message });
        if (error.Code == "booking.gps.rate_limited")
        {
            controller.Response.Headers.RetryAfter = "15";
            return controller.StatusCode(StatusCodes.Status429TooManyRequests,
                new ProblemDetails { Title = error.Code, Detail = error.Message });
        }
        if (error.Code == "booking.gps.unavailable")
        {
            controller.Response.Headers.RetryAfter = "5";
            return controller.StatusCode(StatusCodes.Status503ServiceUnavailable,
                new ProblemDetails { Title = error.Code, Detail = error.Message });
        }

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
