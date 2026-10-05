using FluentValidation;

namespace CareSitter.Modules.Booking.Application.Commands.PostBookingGps;

public sealed class PostBookingGpsCommandValidator : AbstractValidator<PostBookingGpsCommand>
{
    public PostBookingGpsCommandValidator()
    {
        RuleFor(x => x.BookingId).NotEmpty();
        RuleFor(x => x.SessionId).NotEmpty();
        RuleFor(x => x.Latitude).Must(x => double.IsFinite(x) && x is >= -90 and <= 90);
        RuleFor(x => x.Longitude).Must(x => double.IsFinite(x) && x is >= -180 and <= 180);
        RuleFor(x => x.AccuracyMeters).Must(x => x is null || double.IsFinite(x.Value) && x >= 0);
        RuleFor(x => x.Speed).Must(x => x is null || double.IsFinite(x.Value) && x >= 0);
        RuleFor(x => x.Heading).Must(x => x is null || double.IsFinite(x.Value) && x is >= 0 and < 360);
        RuleFor(x => x.CapturedAt).NotEmpty();
    }
}
