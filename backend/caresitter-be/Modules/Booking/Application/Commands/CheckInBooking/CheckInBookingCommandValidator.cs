using FluentValidation;
using FluentValidation.Results;
using Microsoft.Extensions.Options;

namespace CareSitter.Modules.Booking.Application.Commands.CheckInBooking;

public sealed class CheckInBookingCommandValidator : AbstractValidator<CheckInBookingCommand>
{
    public CheckInBookingCommandValidator(IOptions<CheckInOptions> checkInOptions)
    {
        RuleFor(x => x).Custom((command, context) =>
        {
            var policy = checkInOptions.Value;
            if (!IsValidLocation(command.Latitude, command.Longitude))
            {
                context.AddFailure(new ValidationFailure(
                    nameof(command.Latitude), "Tọa độ GPS không hợp lệ.")
                {
                    ErrorCode = BookingErrors.InvalidGpsCode
                });
                return;
            }

            if (command.AccuracyMeters is not null &&
                (!double.IsFinite(command.AccuracyMeters.Value) || command.AccuracyMeters <= 0 ||
                 command.AccuracyMeters > policy.MaxDistanceMeters))
            {
                context.AddFailure(new ValidationFailure(
                    nameof(command.AccuracyMeters),
                    $"Độ chính xác GPS phải nằm trong khoảng 1-{policy.MaxDistanceMeters}m để check-in.")
                {
                    ErrorCode = BookingErrors.InvalidGpsAccuracyCode
                });
            }
        });
    }

    private static bool IsValidLocation(double latitude, double longitude) =>
        double.IsFinite(latitude) && double.IsFinite(longitude) &&
        latitude is >= -90 and <= 90 && longitude is >= -180 and <= 180;
}
