using System.Text.Json;
using CareSitter.Modules.Booking.Controllers;
using CareSitter.SharedKernel.Results;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;

namespace CareSitter.Modules.Booking.UnitTests;

public sealed class BookingResultExtensionsTests
{
    private readonly TestController _controller = new();

    [Fact]
    public void Legacy_validation_error_keeps_anonymous_error_body()
    {
        var result = Assert.IsType<BadRequestObjectResult>(MapFailure(
            Error.Validation("booking.schedule.must_be_future", "Lịch mới phải ở tương lai.")));

        Assert.Equal(StatusCodes.Status400BadRequest, result.StatusCode);
        var body = JsonSerializer.SerializeToElement(result.Value);
        Assert.Equal("Lịch mới phải ở tương lai.", body.GetProperty("error").GetString());
        Assert.Single(body.EnumerateObject());
    }

    [Fact]
    public void Slot_hold_conflict_keeps_legacy_error_and_code_body()
    {
        var result = Assert.IsType<ConflictObjectResult>(MapFailure(
            Error.Conflict("booking.caregiver.slot_held",
                "Caregiver đã được giữ chỗ cho booking khác trong cùng khung giờ.")));

        var body = JsonSerializer.SerializeToElement(result.Value);
        Assert.Equal("Caregiver đã được giữ chỗ cho booking khác trong cùng khung giờ.",
            body.GetProperty("error").GetString());
        Assert.Equal("CAREGIVER_TIME_SLOT_HELD", body.GetProperty("code").GetString());
        Assert.Equal(2, body.EnumerateObject().Count());
    }

    [Fact]
    public void Domain_error_keeps_problem_details_body()
    {
        var result = Assert.IsType<ConflictObjectResult>(MapFailure(
            Error.Conflict("booking.transition", "Không thể chuyển trạng thái.")));
        var problem = Assert.IsType<ProblemDetails>(result.Value);

        Assert.Equal("booking.transition", problem.Title);
        Assert.Equal("Không thể chuyển trạng thái.", problem.Detail);
    }

    [Fact]
    public void Legacy_not_found_keeps_empty_body()
    {
        Assert.IsType<NotFoundResult>(MapFailure(
            Error.NotFound("booking.not_found", string.Empty)));
    }

    [Fact]
    public void Legacy_unauthenticated_keeps_empty_body()
    {
        Assert.IsType<UnauthorizedResult>(MapFailure(
            Error.Unauthorized("booking.unauthenticated", string.Empty)));
    }

    [Fact]
    public void Disabled_gps_keeps_410_error_body()
    {
        var result = Assert.IsType<ObjectResult>(MapFailure(
            Error.Failure("booking.gps_tracking.disabled", "GPS tracking liên tục đã bị tắt.")));

        Assert.Equal(StatusCodes.Status410Gone, result.StatusCode);
        var body = JsonSerializer.SerializeToElement(result.Value);
        Assert.Equal("GPS tracking liên tục đã bị tắt.", body.GetProperty("error").GetString());
        Assert.Single(body.EnumerateObject());
    }

    private IActionResult MapFailure(Error error) =>
        Result.Failure<object>(error).ToActionResult(_controller);

    private sealed class TestController : ControllerBase;
}
