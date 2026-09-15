using CareSitter.Modules.Booking.Application;
using CareSitter.Modules.Booking.Application.Commands.CheckInBooking;
using CareSitter.Modules.Booking.Application.Commands.DeclineBooking;
using CareSitter.Modules.Booking.Application.Commands.UploadCheckInSelfie;
using Microsoft.AspNetCore.Http;
using Microsoft.Extensions.Options;

namespace CareSitter.Modules.Booking.UnitTests;

public sealed class BookingCommandValidatorTests
{
    private static readonly IOptions<CheckInOptions> CheckInPolicy = Options.Create(
        new CheckInOptions { EarlyWindowMinutes = 30, MaxDistanceMeters = 50 });

    [Fact]
    public void CheckIn_rejects_invalid_coordinates_with_legacy_message()
    {
        var validator = new CheckInBookingCommandValidator(CheckInPolicy);

        var result = validator.Validate(new CheckInBookingCommand(Guid.NewGuid(), 91, 106));

        Assert.False(result.IsValid);
        Assert.Equal("Tọa độ GPS không hợp lệ.", result.Errors[0].ErrorMessage);
    }

    [Fact]
    public void CheckIn_rejects_inaccurate_gps_with_legacy_message()
    {
        var validator = new CheckInBookingCommandValidator(CheckInPolicy);

        var result = validator.Validate(new CheckInBookingCommand(Guid.NewGuid(), 10, 106, 51));

        Assert.False(result.IsValid);
        Assert.Equal("Độ chính xác GPS phải nằm trong khoảng 1-50m để check-in.",
            result.Errors[0].ErrorMessage);
    }

    [Fact]
    public void Decline_rejects_reason_longer_than_200_characters_with_legacy_message()
    {
        var validator = new DeclineBookingCommandValidator();

        var result = validator.Validate(new DeclineBookingCommand(Guid.NewGuid(), new string('x', 201)));

        Assert.False(result.IsValid);
        Assert.Equal("Lý do từ chối tối đa 200 ký tự.", result.Errors[0].ErrorMessage);
    }

    [Fact]
    public void Selfie_rejects_empty_file_with_legacy_message()
    {
        var validator = new UploadCheckInSelfieCommandValidator();
        var file = new FormFile(Stream.Null, 0, 0, "file", "selfie.jpg")
        {
            Headers = new HeaderDictionary(),
            ContentType = "image/jpeg"
        };

        var result = validator.Validate(new UploadCheckInSelfieCommand(Guid.NewGuid(), file));

        Assert.False(result.IsValid);
        Assert.Equal("Vui lòng chọn ảnh selfie.", result.Errors[0].ErrorMessage);
    }

    [Fact]
    public void Selfie_rejects_unsupported_content_type_with_legacy_message()
    {
        var validator = new UploadCheckInSelfieCommandValidator();
        var file = new FormFile(new MemoryStream(new byte[] { 1 }), 0, 1, "file", "selfie.gif")
        {
            Headers = new HeaderDictionary(),
            ContentType = "image/gif"
        };

        var result = validator.Validate(new UploadCheckInSelfieCommand(Guid.NewGuid(), file));

        Assert.False(result.IsValid);
        Assert.Equal("Chỉ chấp nhận ảnh JPG, PNG hoặc WEBP.", result.Errors[0].ErrorMessage);
    }
}
