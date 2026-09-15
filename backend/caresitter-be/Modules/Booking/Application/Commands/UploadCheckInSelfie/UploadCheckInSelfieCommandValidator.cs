using FluentValidation;

namespace CareSitter.Modules.Booking.Application.Commands.UploadCheckInSelfie;

public sealed class UploadCheckInSelfieCommandValidator : AbstractValidator<UploadCheckInSelfieCommand>
{
    public UploadCheckInSelfieCommandValidator()
    {
        RuleFor(x => x.File)
            .Cascade(CascadeMode.Stop)
            .Must(file => file is not null && file.Length > 0)
            .WithErrorCode(BookingErrors.SelfieRequiredCode)
            .WithMessage("Vui lòng chọn ảnh selfie.")
            .Must(file => file!.Length <= 10 * 1024 * 1024)
            .WithErrorCode(BookingErrors.SelfieTooLargeCode)
            .WithMessage("Ảnh không được vượt quá 10 MB.")
            .Must(file => file!.ContentType is "image/jpeg" or "image/png" or "image/webp")
            .WithErrorCode(BookingErrors.SelfieInvalidTypeCode)
            .WithMessage("Chỉ chấp nhận ảnh JPG, PNG hoặc WEBP.");
    }
}
