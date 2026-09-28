using FluentValidation;

namespace CareSitter.Modules.Booking.Application.Commands.UploadCheckInSelfie;

public sealed class UploadCheckInSelfieCommandValidator : AbstractValidator<UploadCheckInSelfieCommand>
{
    public UploadCheckInSelfieCommandValidator()
    {
        RuleFor(x => x)
            .Cascade(CascadeMode.Stop)
            .Must(request => request.Content is not null && request.Length > 0)
            .WithErrorCode(BookingErrors.SelfieRequiredCode)
            .WithMessage("Vui lòng chọn ảnh selfie.")
            .Must(request => request.Length <= 10 * 1024 * 1024)
            .WithErrorCode(BookingErrors.SelfieTooLargeCode)
            .WithMessage("Ảnh không được vượt quá 10 MB.")
            .Must(request => AllowedContentTypes.Contains(request.ContentType))
            .WithErrorCode(BookingErrors.SelfieInvalidTypeCode)
            .WithMessage("Chỉ chấp nhận ảnh JPG, PNG hoặc WEBP.");
    }

    private static readonly HashSet<string> AllowedContentTypes =
        new(StringComparer.OrdinalIgnoreCase)
        {
            "image/jpeg", "image/png", "image/webp"
        };
}
