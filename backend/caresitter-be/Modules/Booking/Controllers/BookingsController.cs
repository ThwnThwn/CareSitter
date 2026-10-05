using CareSitter.Modules.Booking.Application;
using CareSitter.Modules.Booking.Application.Bookings.Dtos.Requests;
using CareSitter.Modules.Booking.Application.Bookings.Mapping;
using CareSitter.Modules.Booking.Application.Commands.AcceptBooking;
using CareSitter.Modules.Booking.Application.Commands.CancelBooking;
using CareSitter.Modules.Booking.Application.Commands.CheckInBooking;
using CareSitter.Modules.Booking.Application.Commands.CompleteBooking;
using CareSitter.Modules.Booking.Application.Commands.CreateBooking;
using CareSitter.Modules.Booking.Application.Commands.DeclineBooking;
using CareSitter.Modules.Booking.Application.Commands.RaiseBookingSos;
using CareSitter.Modules.Booking.Application.Commands.RequestBookingCheckout;
using CareSitter.Modules.Booking.Application.Commands.RescheduleBooking;
using CareSitter.Modules.Booking.Application.Commands.SelectCaregiver;
using CareSitter.Modules.Booking.Application.Commands.StartBookingEnRoute;
using CareSitter.Modules.Booking.Application.Commands.UploadCheckInSelfie;
using MediatR;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;

namespace CareSitter.Modules.Booking.Controllers;

/// <summary>
/// Quản lý toàn bộ vòng đời booking chăm sóc:
/// tạo, xem, hủy, dời lịch, chọn caregiver và các bước lifecycle
/// (confirm-payment → accept → en-route → check-in → checkout → complete).
/// </summary>
[ApiController]
[Authorize]
[Route("api/v1/bookings")]
public sealed class BookingsController : ControllerBase
{
    private readonly IMediator _mediator;

    public BookingsController(IMediator mediator)
    {
        _mediator = mediator;
    }

    // ──────────────────────────────────────────────
    //  CRUD
    // ──────────────────────────────────────────────

    /// <summary>Tạo booking mới qua MediatR CreateBookingCommand. Trả về đầy đủ BookingResponse để FE không cần gọi thêm GET.</summary>
    [HttpPost]
    [Authorize(Roles = "CUSTOMER")]
    public async Task<IActionResult> Create([FromBody] CreateBookingRequest request, CancellationToken ct)
    {
        var result = await _mediator.Send(request.ToCommand(), ct);
        return result.ToActionResult(this,
            booking => Created($"/api/v1/bookings/{booking.Id}", booking));
    }

    /// <summary>Lấy danh sách booking của user hiện tại (Customer hoặc Caregiver), có lọc theo status và phân trang.</summary>
    [HttpGet]
    public async Task<IActionResult> List(string? status, int page = 1, int pageSize = 20, CancellationToken ct = default)
    {
        var result = await _mediator.Send(new ListBookingsQuery(status, page, pageSize), ct);
        return result.ToActionResult(this);
    }

    /// <summary>Xem chi tiết một booking theo ID, kiểm tra quyền theo Customer, Caregiver hoặc Admin.</summary>
    [HttpGet("{id:guid}")]
    public async Task<IActionResult> Get(Guid id, CancellationToken ct)
    {
        var result = await _mediator.Send(new GetBookingQuery(id), ct);
        return result.ToActionResult(this);
    }

    // ──────────────────────────────────────────────
    //  DELTA SYNC
    // ──────────────────────────────────────────────

    /// <summary>
    /// Delta sync cho customer app: trả danh sách booking đã thay đổi kể từ cursor X.
    /// Client gọi sau khi nhận SignalR BookingListSync event, sau reconnect hoặc theo polling 30 giây.
    /// </summary>
    [HttpGet("sync")]
    public async Task<IActionResult> Sync([FromQuery] long cursor = 0, CancellationToken ct = default)
    {
        var result = await _mediator.Send(new SyncBookingsQuery(cursor), ct);
        return result.ToActionResult(this);
    }

    /// <summary>
    /// Gợi ý caregiver để customer chọn thủ công.
    /// Dùng cùng bộ lọc/ranking với auto matching nhưng không tạo offer hàng loạt.
    /// </summary>
    [HttpGet("{id:guid}/caregiver-suggestions")]
    [Authorize(Roles = "CUSTOMER")]
    public async Task<IActionResult> GetCaregiverSuggestions(Guid id, int limit = 10, CancellationToken ct = default)
    {
        var result = await _mediator.Send(new GetCaregiverSuggestionsQuery(id, limit), ct);
        return result.ToActionResult(this);
    }

    /// <summary>Hủy booking. Customer có thể hủy ở trạng thái phù hợp; gồm ghi lại lý do.</summary>
    [HttpPost("{id:guid}/cancel")]
    [Authorize(Roles = "CUSTOMER")]
    public async Task<IActionResult> Cancel(Guid id, [FromBody] CancelBookingRequest request, CancellationToken ct)
    {
        var result = await _mediator.Send(new CancelBookingCommand(id, request.Reason), ct);
        return result.ToActionResult(this);
    }

    /// <summary>Dời lịch booking. Tính lại giá và kiểm tra caregiver còn rảnh trong khung giờ mới.</summary>
    [HttpPut("{id:guid}/schedule")]
    [Authorize(Roles = "CUSTOMER")]
    public async Task<IActionResult> Reschedule(Guid id, [FromBody] RescheduleBookingRequest request, CancellationToken ct)
    {
        var result = await _mediator.Send(new RescheduleBookingCommand(
            id, request.ScheduledStart, request.ScheduledEnd), ct);
        return result.ToActionResult(this);
    }

    /// <summary>Chọn caregiver cho booking. Kiểm tra lịch trống trước khi gán.</summary>
    [HttpPut("{id:guid}/caregiver")]
    [Authorize(Roles = "CUSTOMER")]
    public async Task<IActionResult> SelectCaregiver(Guid id, [FromBody] SelectCaregiverRequest request, CancellationToken ct)
    {
        var result = await _mediator.Send(new SelectCaregiverCommand(id, request.CaregiverId), ct);
        return result.ToActionResult(this);
    }

    // ──────────────────────────────────────────────
    //  LIFECYCLE
    // ──────────────────────────────────────────────

    [HttpPost("{id:guid}/accept")]
    [Authorize(Roles = "CAREGIVER")]
    public async Task<IActionResult> Accept(Guid id, CancellationToken ct)
    {
        var result = await _mediator.Send(new AcceptBookingCommand(id), ct);
        return result.ToActionResult(this);
    }

    /// <summary>Caregiver từ chối một ca mở để ca đó không hiển thị lại cho caregiver này.</summary>
    [HttpPost("{id:guid}/decline")]
    [Authorize(Roles = "CAREGIVER")]
    public async Task<IActionResult> Decline(Guid id, [FromBody] DeclineBookingRequest? request,
        CancellationToken ct)
    {
        var result = await _mediator.Send(new DeclineBookingCommand(id, request?.Reason), ct);
        return result.ToActionResult(this, _ => NoContent());
    }

    /// <summary>Caregiver bắt đầu di chuyển đến nơi chăm sóc, chuyển sang EN_ROUTE.</summary>
    [HttpPost("{id:guid}/en-route")]
    [Authorize(Roles = "CAREGIVER")]
    public async Task<IActionResult> StartEnRoute(Guid id, CancellationToken ct)
    {
        var result = await _mediator.Send(new StartBookingEnRouteCommand(id), ct);
        return result.ToActionResult(this);
    }

    /// <summary>
    /// Caregiver check-in tại địa chỉ chăm sóc. Kiểm tra khoảng cách GPS với geofence.
    /// Ghi GPS track và timeline sự kiện CHECKIN_VALID / CHECKIN_OUTSIDE_GEOFENCE.
    /// </summary>
    [HttpPost("{id:guid}/check-in")]
    [Authorize(Roles = "CAREGIVER")]
    public async Task<IActionResult> CheckIn(Guid id, [FromBody] CheckInRequest request, CancellationToken ct)
    {
        var result = await _mediator.Send(new CheckInBookingCommand(
            id, request.Latitude, request.Longitude, request.AccuracyMeters), ct);
        return result.ToActionResult(this);
    }

    /// <summary>Caregiver upload selfie minh chứng trước khi check-in GPS.</summary>
    [HttpPost("{id:guid}/check-in/selfie")]
    [Authorize(Roles = "CAREGIVER")]
    [RequestSizeLimit(10 * 1024 * 1024)]
    public async Task<IActionResult> UploadCheckInSelfie(Guid id, IFormFile? file, CancellationToken ct)
    {
        await using var stream = file?.OpenReadStream();
        var result = await _mediator.Send(new UploadCheckInSelfieCommand(
            id, stream, file?.FileName ?? string.Empty,
            file?.ContentType ?? string.Empty, file?.Length ?? 0), ct);
        return result.ToActionResult(this);
    }

    /// <summary>Caregiver gửi yêu cầu checkout thủ công (khi chưa auto-checkout).</summary>
    [HttpPost("{id:guid}/checkout/request")]
    [Authorize(Roles = "CAREGIVER")]
    public async Task<IActionResult> RequestCheckout(Guid id, CancellationToken ct)
    {
        var result = await _mediator.Send(new RequestBookingCheckoutCommand(id), ct);
        return result.ToActionResult(this);
    }

    /// <summary>
    /// Customer/Admin xác nhận checkout rồi mới hoàn tất ca và giải ngân escrow.
    /// Caregiver chỉ được yêu cầu checkout qua /checkout/request.
    /// </summary>
    [HttpPost("{id:guid}/complete")]
    [Authorize(Roles = "CUSTOMER,ADMIN")]
    public async Task<IActionResult> Complete(Guid id, CancellationToken ct)
    {
        var result = await _mediator.Send(new CompleteBookingCommand(id), ct);
        return result.ToActionResult(this);
    }

    /// <summary>
    /// Kích hoạt SOS khẩn cấp trong ca chăm sóc.
    /// Cả Customer và Caregiver được assign đều có thể bấm SOS. Admin cũng được phép.
    /// </summary>
    [HttpPost("{id:guid}/sos")]
    [Authorize(Roles = "CUSTOMER,CAREGIVER,ADMIN")]
    public async Task<IActionResult> RaiseSos(Guid id, CancellationToken ct)
    {
        var result = await _mediator.Send(new RaiseBookingSosCommand(id), ct);
        return result.ToActionResult(this);
    }

}
