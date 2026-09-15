using CareSitter.Contracts.Services;
using CareSitter.Infrastructure.Security;
using CareSitter.Infrastructure.Time;
using CareSitter.Modules.Booking.Application;
using CareSitter.Modules.Booking.Application.Commands.AcceptBooking;
using CareSitter.Modules.Booking.Application.Commands.CancelBooking;
using CareSitter.Modules.Booking.Application.Commands.CheckInBooking;
using CareSitter.Modules.Booking.Application.Commands.CompleteBooking;
using CareSitter.Modules.Booking.Application.Commands.ConfirmBookingPayment;
using CareSitter.Modules.Booking.Application.Commands.CreateBooking;
using CareSitter.Modules.Booking.Application.Commands.DeclineBooking;
using CareSitter.Modules.Booking.Application.Commands.RaiseBookingSos;
using CareSitter.Modules.Booking.Application.Commands.RequestBookingCheckout;
using CareSitter.Modules.Booking.Application.Commands.RescheduleBooking;
using CareSitter.Modules.Booking.Application.Commands.SelectCaregiver;
using CareSitter.Modules.Booking.Application.Commands.StartBookingEnRoute;
using CareSitter.Modules.Booking.Application.Commands.UploadCheckInSelfie;
using CareSitter.Modules.Booking.Application.Sync;
using CareSitter.Modules.Booking.Domain;
using CareSitter.Modules.Booking.Infrastructure;
using MediatR;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace CareSitter.Modules.Booking.Controllers;

/// <summary>
/// Quản lý toàn bộ vòng đời booking chăm sóc:
/// tạo, xem, hủy, dời lịch, chọn caregiver và các bước lifecycle
/// (confirm-payment → accept → en-route → check-in → checkout → complete).
/// </summary>
[ApiController]
[Authorize]
[Route("api/v1/bookings")]
public sealed class BookingsController(
    BookingDbContext db, ICurrentUser currentUser, IClock clock,
    IPeopleLookupService people,
    IMatchingService matching,
    ISender sender,
    BookingSyncService bookingSync,
    BookingResponseMapper responseMapper) : ControllerBase
{
    // ──────────────────────────────────────────────
    //  CRUD
    // ──────────────────────────────────────────────

    /// <summary>Tạo booking mới qua MediatR CreateBookingCommand. Trả về đầy đủ BookingResponse để FE không cần gọi thêm GET.</summary>
    [HttpPost]
    public async Task<IActionResult> Create([FromBody] CreateBookingCommand command, CancellationToken ct)
    {
        var result = await sender.Send(command, ct);
        return result.ToActionResult(this,
            booking => Created($"/api/v1/bookings/{booking.Id}", booking));
    }

    /// <summary>Lấy danh sách booking của user hiện tại (Customer hoặc Caregiver), có lọc theo status và phân trang.</summary>
    [HttpGet]
    public async Task<IActionResult> List(string? status, int page = 1, int pageSize = 20, CancellationToken ct = default)
    {
        if (currentUser.UserId is not { } userId) return Unauthorized();
        page = Math.Max(page, 1);
        pageSize = Math.Clamp(pageSize, 1, 50);

        IQueryable<Domain.Booking> query;
        Guid? caregiverProfileId = null;
        var isOfferInbox = false;

        if (currentUser.IsInRole("ADMIN"))
        {
            query = db.Bookings.AsNoTracking();
        }
        else if (currentUser.IsInRole("CAREGIVER"))
        {
            caregiverProfileId = await people.GetCaregiverProfileIdByUserIdAsync(userId, ct);
            if (caregiverProfileId is null)
                return Ok(new { items = Array.Empty<BookingResponse>(), total = 0, page, pageSize });

            if (string.Equals(status, "open", StringComparison.OrdinalIgnoreCase) ||
                string.Equals(status, "available", StringComparison.OrdinalIgnoreCase))
            {
                var personalizedIds = await matching.GetOpenBookingIdsForCaregiverAsync(
                    caregiverProfileId.Value, ct);
                query = db.Bookings.AsNoTracking().Where(x => personalizedIds.Contains(x.Id));
                isOfferInbox = true;
                status = null; // Đã lọc xong
            }
            else
            {
                query = db.Bookings.AsNoTracking().Where(x => x.CaregiverId == caregiverProfileId.Value);
            }
        }
        else
        {
            query = db.Bookings.AsNoTracking().Where(x => x.CustomerId == userId);
        }

        if (!string.IsNullOrWhiteSpace(status))
        {
            if (!Enum.TryParse<BookingStatus>(status.Replace("_", string.Empty), true, out var parsed))
                return BadRequest(new { error = "Trạng thái booking không hợp lệ." });
            query = query.Where(x => x.Status == parsed);
        }

        // Capture the cursor before the list snapshot. A mutation after this
        // point remains visible to the client's following delta request.
        var syncCursor = 0L;
        if (currentUser.IsInRole("CUSTOMER") && currentUser.UserId is { } cid)
            syncCursor = await bookingSync.GetCurrentCursorAsync(cid, ct);

        var total = await query.CountAsync(ct);
        var orderedQuery = isOfferInbox
            ? query.OrderBy(x => x.ScheduledStart)
            : query.OrderByDescending(x => x.ScheduledStart);
        var items = await orderedQuery
            .Skip((page - 1) * pageSize).Take(pageSize).ToListAsync(ct);
        var responses = await responseMapper.ToResponsesAsync(items, ct,
            offerCaregiverId: isOfferInbox ? caregiverProfileId : null);

        return Ok(new { items = responses, total, page, pageSize, syncCursor });
    }

    /// <summary>Xem chi tiết một booking theo ID, kiểm tra quyền theo Customer, Caregiver hoặc Admin.</summary>
    [HttpGet("{id:guid}")]
    public async Task<IActionResult> Get(Guid id, CancellationToken ct)
    {
        if (currentUser.UserId is not { } userId) return Unauthorized();
        var entity = await db.Bookings.AsNoTracking().SingleOrDefaultAsync(x => x.Id == id, ct);
        if (entity is null) return NotFound();

        bool isCustomer = entity.CustomerId == userId;
        bool isAdmin = currentUser.IsInRole("ADMIN");
        bool isCaregiver = false;

        if (!isCustomer && !isAdmin && currentUser.IsInRole("CAREGIVER"))
        {
            var caregiverProfileId = await people.GetCaregiverProfileIdByUserIdAsync(userId, ct);
            if (caregiverProfileId.HasValue)
            {
                isCaregiver = entity.CaregiverId == caregiverProfileId.Value
                    || await db.BookingAssignments.AsNoTracking().AnyAsync(x =>
                        x.BookingId == entity.Id && x.CaregiverId == caregiverProfileId.Value
                        && (x.Status == "OFFERED" || x.Status == "SUGGESTED")
                        && x.ExpiresAt != null && x.ExpiresAt > clock.UtcNow, ct);
            }
        }

        if (!isCustomer && !isCaregiver && !isAdmin)
            return Forbid();

        return Ok(await responseMapper.ToResponseAsync(entity, ct));
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
        if (currentUser.UserId is not { } userId) return Unauthorized();
        if (!currentUser.IsInRole("CUSTOMER") && !currentUser.IsInRole("ADMIN"))
            return Forbid();

        var delta = await bookingSync.GetDeltaAsync(userId, cursor, batchSize: 100, ct);

        if (delta.ResetRequired)
            return Ok(new { resetRequired = true, nextCursor = 0L, serverTime = DateTimeOffset.UtcNow });

        if (delta.Events.Count == 0)
            return Ok(new
            {
                items = Array.Empty<BookingResponse>(),
                nextCursor = delta.NextCursor,
                serverTime = DateTimeOffset.UtcNow,
                hasMore = false,
                resetRequired = false
            });

        // Lấy các booking ID không trùng từ events rồi query snapshot đầy đủ
        var bookingIds = delta.Events.Select(e => e.BookingId).Distinct().ToList();
        var bookings = await db.Bookings.AsNoTracking()
            .Where(b => bookingIds.Contains(b.Id))
            .ToListAsync(ct);
        var responses = await responseMapper.ToResponsesAsync(bookings, ct);

        return Ok(new
        {
            items = responses,
            nextCursor = delta.NextCursor,
            serverTime = DateTimeOffset.UtcNow,
            hasMore = delta.HasMore,
            resetRequired = false
        });
    }

    /// <summary>
    /// Gợi ý caregiver để customer chọn thủ công.
    /// Dùng cùng bộ lọc/ranking với auto matching nhưng không tạo offer hàng loạt.
    /// </summary>
    [HttpGet("{id:guid}/caregiver-suggestions")]
    public async Task<IActionResult> GetCaregiverSuggestions(Guid id, int limit = 10, CancellationToken ct = default)
    {
        if (currentUser.UserId is not { } userId) return Unauthorized();
        limit = Math.Clamp(limit, 1, 20);

        var booking = await db.Bookings.AsNoTracking()
            .SingleOrDefaultAsync(x => x.Id == id, ct);
        if (booking is null) return NotFound();
        if (booking.CustomerId != userId && !currentUser.IsInRole("ADMIN"))
            return Forbid();
        if (booking.CaregiverId.HasValue)
            return Ok(new { items = Array.Empty<CaregiverSuggestionResponse>(), total = 0 });

        var candidates = await matching.GetSuggestedCaregiversAsync(id, ct);
        var items = new List<CaregiverSuggestionResponse>();
        foreach (var candidate in candidates.Take(limit))
        {
            var display = await people.GetCaregiverDisplayAsync(candidate.CaregiverId, ct);
            items.Add(BookingResponseMapper.ToCaregiverSuggestion(candidate, display));
        }

        return Ok(new { items, total = candidates.Count });
    }

    /// <summary>Hủy booking. Customer có thể hủy ở trạng thái phù hợp; gồm ghi lại lý do.</summary>
    [HttpPost("{id:guid}/cancel")]
    public async Task<IActionResult> Cancel(Guid id, [FromBody] CancelBookingRequest request, CancellationToken ct)
    {
        var result = await sender.Send(new CancelBookingCommand(id, request.Reason), ct);
        return result.ToActionResult(this);
    }

    /// <summary>Dời lịch booking. Tính lại giá và kiểm tra caregiver còn rảnh trong khung giờ mới.</summary>
    [HttpPut("{id:guid}/schedule")]
    public async Task<IActionResult> Reschedule(Guid id, [FromBody] RescheduleBookingRequest request, CancellationToken ct)
    {
        var result = await sender.Send(new RescheduleBookingCommand(
            id, request.ScheduledStart, request.ScheduledEnd), ct);
        return result.ToActionResult(this);
    }

    /// <summary>Chọn caregiver cho booking. Kiểm tra lịch trống trước khi gán.</summary>
    [HttpPut("{id:guid}/caregiver")]
    public async Task<IActionResult> SelectCaregiver(Guid id, [FromBody] SelectCaregiverRequest request, CancellationToken ct)
    {
        var result = await sender.Send(new SelectCaregiverCommand(id, request.CaregiverId), ct);
        return result.ToActionResult(this);
    }

    // ──────────────────────────────────────────────
    //  LIFECYCLE
    // ──────────────────────────────────────────────

    /// <summary>Khóa escrow thanh toán qua WalletService rồi chuyển booking sang trạng thái PAYMENT_CONFIRMED.</summary>
    [HttpPost("{id:guid}/confirm-payment")]
    public async Task<IActionResult> ConfirmPayment(Guid id, CancellationToken ct)
    {
        var result = await sender.Send(new ConfirmBookingPaymentCommand(id), ct);
        return result.ToActionResult(this);
    }

    [HttpPost("{id:guid}/accept")]
    public async Task<IActionResult> Accept(Guid id, CancellationToken ct)
    {
        var result = await sender.Send(new AcceptBookingCommand(id), ct);
        return result.ToActionResult(this);
    }

    /// <summary>Caregiver từ chối một ca mở để ca đó không hiển thị lại cho caregiver này.</summary>
    [HttpPost("{id:guid}/decline")]
    public async Task<IActionResult> Decline(Guid id, [FromBody] DeclineBookingRequest? request,
        CancellationToken ct)
    {
        var result = await sender.Send(new DeclineBookingCommand(id, request?.Reason), ct);
        return result.ToActionResult(this, _ => NoContent());
    }

    /// <summary>Caregiver bắt đầu di chuyển đến nơi chăm sóc, chuyển sang EN_ROUTE.</summary>
    [HttpPost("{id:guid}/en-route")]
    public async Task<IActionResult> StartEnRoute(Guid id, CancellationToken ct)
    {
        var result = await sender.Send(new StartBookingEnRouteCommand(id), ct);
        return result.ToActionResult(this);
    }

    /// <summary>
    /// Caregiver check-in tại địa chỉ chăm sóc. Kiểm tra khoảng cách GPS với geofence.
    /// Ghi GPS track và timeline sự kiện CHECKIN_VALID / CHECKIN_OUTSIDE_GEOFENCE.
    /// </summary>
    [HttpPost("{id:guid}/check-in")]
    public async Task<IActionResult> CheckIn(Guid id, [FromBody] CheckInRequest request, CancellationToken ct)
    {
        var result = await sender.Send(new CheckInBookingCommand(
            id, request.Latitude, request.Longitude, request.AccuracyMeters), ct);
        return result.ToActionResult(this);
    }

    /// <summary>Caregiver upload selfie minh chứng trước khi check-in GPS.</summary>
    [HttpPost("{id:guid}/check-in/selfie")]
    [RequestSizeLimit(10 * 1024 * 1024)]
    public async Task<IActionResult> UploadCheckInSelfie(Guid id, IFormFile file, CancellationToken ct)
    {
        var result = await sender.Send(new UploadCheckInSelfieCommand(id, file), ct);
        return result.ToActionResult(this);
    }

    /// <summary>Caregiver gửi yêu cầu checkout thủ công (khi chưa auto-checkout).</summary>
    [HttpPost("{id:guid}/checkout/request")]
    public async Task<IActionResult> RequestCheckout(Guid id, CancellationToken ct)
    {
        var result = await sender.Send(new RequestBookingCheckoutCommand(id), ct);
        return result.ToActionResult(this);
    }

    /// <summary>
    /// Customer/Admin xác nhận checkout rồi mới hoàn tất ca và giải ngân escrow.
    /// Caregiver chỉ được yêu cầu checkout qua /checkout/request.
    /// </summary>
    [HttpPost("{id:guid}/complete")]
    public async Task<IActionResult> Complete(Guid id, CancellationToken ct)
    {
        var result = await sender.Send(new CompleteBookingCommand(id), ct);
        return result.ToActionResult(this);
    }

    /// <summary>
    /// Kích hoạt SOS khẩn cấp trong ca chăm sóc.
    /// Cả Customer và Caregiver được assign đều có thể bấm SOS. Admin cũng được phép.
    /// </summary>
    [HttpPost("{id:guid}/sos")]
    public async Task<IActionResult> RaiseSos(Guid id, CancellationToken ct)
    {
        var result = await sender.Send(new RaiseBookingSosCommand(id), ct);
        return result.ToActionResult(this);
    }

}

// ── DTOs ──
public sealed record CancelBookingRequest(string? Reason);
public sealed record RescheduleBookingRequest(DateTimeOffset ScheduledStart, DateTimeOffset ScheduledEnd);
public sealed record SelectCaregiverRequest(Guid CaregiverId);
public sealed record CheckInRequest(double Latitude, double Longitude, double? AccuracyMeters = null);
public sealed record DeclineBookingRequest(string? Reason);
