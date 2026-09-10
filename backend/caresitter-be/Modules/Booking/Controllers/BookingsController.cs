using CareSitter.Contracts.Services;
using CareSitter.Infrastructure.Hubs;
using CareSitter.Infrastructure.Security;
using CareSitter.Infrastructure.Time;
using CareSitter.Modules.Booking.Application.CreateBooking;
using CareSitter.Modules.Booking.Domain;
using CareSitter.Modules.Booking.Infrastructure;
using CareSitter.SharedKernel.Results;
using CareSitter.SharedKernel.ValueObjects;
using MediatR;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.SignalR;
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
    IPricingService pricing, IPeopleLookupService people,
    IWalletService wallet, ICatalogLookupService catalog,
    IMatchingService matching,
    IDisputeLookupService disputeLookup,
    ISender sender,
    IHubContext<CareTrackingHub> hub,
    IUserNotificationService notifications) : ControllerBase
{
    // ════════════════════════════════════════════
    //  CRUD
    // ════════════════════════════════════════════

    /// <summary>Tạo booking mới qua MediatR CreateBookingCommand. Trả về full BookingResponse để FE không cần gọi thêm GET.</summary>
    [HttpPost]
    public async Task<IActionResult> Create([FromBody] CreateBookingCommand command, CancellationToken ct)
    {
        var result = await sender.Send(command, ct);
        if (result.IsFailure) return Problem(result.Error);

        // Query lại để lấy entity đầy đủ (handler chỉ trả Guid)
        var booking = await db.Bookings.AsNoTracking()
            .SingleAsync(x => x.Id == result.Value, ct);
        return Created($"/api/v1/bookings/{booking.Id}", await ToResponseAsync(booking, ct));
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
                status = null; // đã filter xong
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
                return BadRequest(new { error = "Trang thai booking khong hop le." });
            query = query.Where(x => x.Status == parsed);
        }

        var total = await query.CountAsync(ct);
        var items = await query.OrderByDescending(x => x.ScheduledStart)
            .Skip((page - 1) * pageSize).Take(pageSize).ToListAsync(ct);
        var responses = await ToResponsesAsync(items, ct);
        return Ok(new { items = responses, total, page, pageSize });
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
            isCaregiver = caregiverProfileId.HasValue && entity.CaregiverId == caregiverProfileId.Value;
        }

        if (!isCustomer && !isCaregiver && !isAdmin)
            return Forbid();

        return Ok(await ToResponseAsync(entity, ct));
    }

    /// <summary>
    /// Gợi ý caregiver cho customer chọn thủ công.
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
            items.Add(ToCaregiverSuggestion(candidate, display));
        }

        return Ok(new { items, total = candidates.Count });
    }

    /// <summary>Hủy booking. Customer có thể hủy ở trạng thái phù hợp; gồm ghi lại lý do.</summary>
    [HttpPost("{id:guid}/cancel")]
    public async Task<IActionResult> Cancel(Guid id, [FromBody] CancelBookingRequest request, CancellationToken ct)
    {
        if (currentUser.UserId is not { } userId) return Unauthorized();
        var booking = await db.Bookings.SingleOrDefaultAsync(x =>
            x.Id == id && x.CustomerId == userId, ct);
        if (booking is null) return NotFound();
        var oldStatus = BookingStatusCodec.ToApi(booking.Status);
        var result = booking.Cancel(userId, "CUSTOMER", request.Reason, clock.UtcNow);
        if (result.IsFailure) return Problem(result.Error);
        await db.SaveChangesAsync(ct);
        await hub.Clients.Group(CareTrackingHub.BookingGroup(id))
            .SendAsync("BookingStatusChanged", new BookingStatusChangedEvent(
                id, oldStatus, "cancelled", DateTimeOffset.UtcNow), ct);
        await NotifyCaregiverAsync(booking, "Lịch chăm sóc đã bị hủy",
            "Khách hàng đã hủy lịch chăm sóc.", ct);
        return Ok(await ToResponseAsync(booking, ct));
    }

    /// <summary>Dời lịch booking. Tính lại giá và kiểm tra caregiver cón rảnh trong khung giờ mới.</summary>
    [HttpPut("{id:guid}/schedule")]
    public async Task<IActionResult> Reschedule(Guid id, [FromBody] RescheduleBookingRequest request, CancellationToken ct)
    {
        if (currentUser.UserId is not { } userId) return Unauthorized();
        if (request.ScheduledStart <= clock.UtcNow) return BadRequest(new { error = "Lich moi phai o tuong lai." });
        var booking = await db.Bookings.SingleOrDefaultAsync(x => x.Id == id && x.CustomerId == userId, ct);
        if (booking is null) return NotFound();
        if (booking.CaregiverId is { } caregiverId && !await people.CaregiverIsAvailableAsync(
            caregiverId, request.ScheduledStart, request.ScheduledEnd, ct))
            return Conflict(new { error = "Caregiver khong ranh trong lich moi." });

        var quote = await pricing.QuoteAsync(booking.ServiceTypeId,
            request.ScheduledStart, request.ScheduledEnd, ct);
        if (quote.IsFailure) return Problem(quote.Error);
        var changed = booking.Reschedule(request.ScheduledStart, request.ScheduledEnd);
        if (changed.IsFailure) return Problem(changed.Error);
        booking.ApplyPricing(quote.Value.EscrowAmount, quote.Value.PlatformFeeAmount,
            quote.Value.CaregiverEarningAmount, quote.Value.PriceSnapshotJson);
        await db.SaveChangesAsync(ct);
        return Ok(await ToResponseAsync(booking, ct));
    }

    /// <summary>Chọn caregiver cho booking. Kiểm tra rảnh lịch trước khi gán.</summary>
    [HttpPut("{id:guid}/caregiver")]
    public async Task<IActionResult> SelectCaregiver(Guid id, [FromBody] SelectCaregiverRequest request, CancellationToken ct)
    {
        if (currentUser.UserId is not { } userId) return Unauthorized();
        var booking = await db.Bookings.SingleOrDefaultAsync(x =>
            x.Id == id && x.CustomerId == userId, ct);
        if (booking is null) return NotFound();
        if (!await people.CaregiverIsAvailableAsync(request.CaregiverId,
            booking.ScheduledStart, booking.ScheduledEnd, ct))
            return Conflict(new { error = "Caregiver khong ranh trong khung gio nay." });
        var suggestions = await matching.GetSuggestedCaregiversAsync(id, ct);
        if (!suggestions.Any(x => x.CaregiverId == request.CaregiverId))
            return Conflict(new { error = "Caregiver khong nam trong danh sach goi y phu hop cua ca nay." });
        var result = booking.SelectCaregiver(request.CaregiverId);
        if (result.IsFailure) return Problem(result.Error);
        await db.SaveChangesAsync(ct);
        if (booking.Status == BookingStatus.Confirmed)
        {
            await NotifyCaregiverAsync(booking, "Bạn có lịch chăm sóc mới",
                "Khách hàng đã thanh toán và đang chờ bạn xác nhận ca.", ct);
        }
        return Ok(await ToResponseAsync(booking, ct));
    }

    // ════════════════════════════════════════════
    //  LIFECYCLE
    // ════════════════════════════════════════════

    /// <summary>Khóa escrow thanh toán qua WalletService rồi chuyển booking sang trạng thái PAYMENT_CONFIRMED.</summary>
    [HttpPost("{id:guid}/confirm-payment")]
    public async Task<IActionResult> ConfirmPayment(Guid id, CancellationToken ct)
    {
        if (currentUser.UserId is not { } userId) return Unauthorized();
        var booking = await db.Bookings.SingleOrDefaultAsync(x => x.Id == id && x.CustomerId == userId, ct);
        if (booking is null) return NotFound();

        var lockResult = await wallet.LockEscrowAsync(booking.Id, booking.EscrowAmount,
            $"booking-escrow-{booking.Id}", ct);
        if (lockResult.IsFailure) return Problem(lockResult.Error);

        var result = booking.ConfirmPayment();
        if (result.IsFailure) return Problem(result.Error);
        await db.SaveChangesAsync(ct);
        await matching.OfferTopCandidatesAsync(id, ct);
        await NotifyCaregiverAsync(booking, "Bạn có lịch chăm sóc mới",
            "Khách hàng đã thanh toán và đang chờ bạn xác nhận ca.", ct);
        return Ok(await ToResponseAsync(booking, ct));
    }

    /// <summary>Caregiver chấp nhận ca, chuyển booking sang ASSIGNED và ghi timeline CHECKIN.</summary>
    [HttpPost("{id:guid}/accept")]
    public async Task<IActionResult> Accept(Guid id, CancellationToken ct)
    {
        if (currentUser.UserId is not { } userId) return Unauthorized();
        var booking = await db.Bookings.SingleOrDefaultAsync(x => x.Id == id, ct);
        if (booking is null) return NotFound();
        if (!currentUser.IsInRole("CAREGIVER")) return Forbid();

        Guid caregiverId;
        if (booking.CaregiverId is { } assignedCaregiverId)
        {
            if (!await people.IsCaregiverForBookingAsync(assignedCaregiverId, userId, ct))
                return Forbid();
            caregiverId = assignedCaregiverId;
        }
        else
        {
            var currentCaregiverId = await people.GetCaregiverProfileIdByUserIdAsync(userId, ct);
            if (currentCaregiverId is null) return Forbid();
            caregiverId = currentCaregiverId.Value;

            var offer = await db.BookingAssignments.AsNoTracking().SingleOrDefaultAsync(x =>
                x.BookingId == id && x.CaregiverId == caregiverId
                && (x.Status == "OFFERED" || x.Status == "SUGGESTED")
                && (x.ExpiresAt == null || x.ExpiresAt > DateTimeOffset.UtcNow), ct);
            var hasAnyAssignment = await db.BookingAssignments.AsNoTracking()
                .AnyAsync(x => x.BookingId == id, ct);
            if (offer is null && hasAnyAssignment)
                return Conflict(new { error = "Ca nay khong con offer hop le cho caregiver nay." });

            if (offer is null)
            {
                var eligible = await matching.GetEligibleCaregiversAsync(id, ct);
                if (!eligible.Any(x => x.CaregiverId == caregiverId))
                    return Conflict(new { error = "Caregiver khong nam trong tap phu hop cua ca nay." });
            }
        }

        if (!await people.CaregiverIsAvailableAsync(
                caregiverId, booking.ScheduledStart, booking.ScheduledEnd, ct))
            return Conflict(new { error = "Caregiver khong ranh trong khung gio nay." });

        if (await HasCaregiverScheduleConflictAsync(booking.Id, caregiverId,
                booking.ScheduledStart, booking.ScheduledEnd, ct))
            return Conflict(new { error = "Caregiver da co ca cham soc trong khung gio nay." });

        if (booking.CaregiverId.HasValue && booking.CaregiverId != caregiverId)
            return Conflict(new { error = "Ca này vừa được nhận bởi người chăm sóc khác." });
        if (booking.Status != BookingStatus.Confirmed && booking.Status != BookingStatus.Crisis)
            return Conflict(new { error = "Ca này không còn ở trạng thái chờ nhận." });

        var oldStatus = BookingStatusCodec.ToApi(booking.Status);
        var result = booking.AssignCaregiver(caregiverId);
        if (result.IsFailure) return Problem(result.Error);
        var acceptedOffer = await db.BookingAssignments.SingleOrDefaultAsync(x =>
            x.BookingId == id && x.CaregiverId == caregiverId
            && (x.Status == "OFFERED" || x.Status == "SUGGESTED"), ct);
        acceptedOffer?.Accept();
        var otherOffers = await db.BookingAssignments
            .Where(x => x.BookingId == id && x.CaregiverId != caregiverId && x.Status == "OFFERED")
            .ToListAsync(ct);
        foreach (var otherOffer in otherOffers)
            otherOffer.Cancel();
        db.TimelineEvents.Add(CareTimelineEvent.Create(
            booking.Id, caregiverId, "CHECKIN", "Caregiver da nhan ca"));

        try
        {
            await db.SaveChangesAsync(ct);
        }
        catch (DbUpdateException)
        {
            return Conflict(new { error = "Ca này vừa được nhận bởi người chăm sóc khác." });
        }

        await hub.Clients.Group(CareTrackingHub.BookingGroup(id))
            .SendAsync("BookingStatusChanged", new BookingStatusChangedEvent(
                id, oldStatus, "caregiver_accepted", DateTimeOffset.UtcNow), ct);
        await NotifyBookingUserAsync(booking.CustomerId, booking, "Caregiver đã nhận ca",
            "Caregiver đã xác nhận lịch chăm sóc của bạn.", ct);
        return Ok(await ToResponseAsync(booking, ct));
    }

    /// <summary>Caregiver từ chối một ca mở để ca đó không hiển thị lại cho caregiver này.</summary>
    [HttpPost("{id:guid}/decline")]
    public async Task<IActionResult> Decline(Guid id, CancellationToken ct)
    {
        if (currentUser.UserId is not { } userId) return Unauthorized();
        if (!currentUser.IsInRole("CAREGIVER")) return Forbid();

        var caregiverId = await people.GetCaregiverProfileIdByUserIdAsync(userId, ct);
        if (caregiverId is null) return Forbid();

        var booking = await db.Bookings.AsNoTracking().SingleOrDefaultAsync(x => x.Id == id, ct);
        if (booking is null) return NotFound();

        if (booking.CaregiverId.HasValue || booking.Status != BookingStatus.Confirmed)
            return Conflict(new { error = "Ca nay khong con mo de tu choi." });

        var assignment = await db.BookingAssignments.SingleOrDefaultAsync(
            x => x.BookingId == id && x.CaregiverId == caregiverId.Value, ct);

        if (assignment is null)
        {
            db.BookingAssignments.Add(BookingAssignment.CreateRejected(id, caregiverId.Value));
        }
        else
        {
            assignment.Reject();
        }

        await db.SaveChangesAsync(ct);
        var hasActiveOffer = await db.BookingAssignments.AsNoTracking().AnyAsync(x =>
            x.BookingId == id && (x.Status == "OFFERED" || x.Status == "SUGGESTED")
            && (x.ExpiresAt == null || x.ExpiresAt > DateTimeOffset.UtcNow), ct);
        if (!hasActiveOffer)
            await matching.OfferTopCandidatesAsync(id, ct);

        return NoContent();
    }

    /// <summary>Caregiver bắt đầu di chuyển đến nơi chăm sóc, chuyển sang EN_ROUTE.</summary>
    [HttpPost("{id:guid}/en-route")]
    public async Task<IActionResult> StartEnRoute(Guid id, CancellationToken ct)
    {
        if (currentUser.UserId is not { } userId) return Unauthorized();
        var booking = await db.Bookings.SingleOrDefaultAsync(x => x.Id == id, ct);
        if (booking is null) return NotFound();
        if (booking.CaregiverId is not { } caregiverId)
            return BadRequest(new { error = "Booking chua co caregiver." });
        if (!await people.IsCaregiverForBookingAsync(caregiverId, userId, ct))
            return Forbid();

        var oldStatus = BookingStatusCodec.ToApi(booking.Status);
        var result = booking.StartEnRoute();
        if (result.IsFailure) return Problem(result.Error);
        db.TimelineEvents.Add(CareTimelineEvent.Create(
            booking.Id, caregiverId, "CHECKIN", "Caregiver dang tren duong den"));
        await db.SaveChangesAsync(ct);
        await hub.Clients.Group(CareTrackingHub.BookingGroup(id))
            .SendAsync("BookingStatusChanged", new BookingStatusChangedEvent(
                id, oldStatus, BookingStatusCodec.ToApi(booking.Status), DateTimeOffset.UtcNow), ct);
        await NotifyBookingUserAsync(booking.CustomerId, booking, "Caregiver đang di chuyển",
            "Caregiver đang trên đường đến địa điểm chăm sóc.", ct);
        return Ok(await ToResponseAsync(booking, ct));
    }

    /// <summary>
    /// Caregiver check-in tại địa chỉ chăm sóc. Kiểm tra khoảng cách GPS với geofence.
    /// Ghi GPS track và timeline sự kiện CHECKIN_VALID / CHECKIN_OUTSIDE_GEOFENCE.
    /// </summary>
    [HttpPost("{id:guid}/check-in")]
    public async Task<IActionResult> CheckIn(Guid id, [FromBody] CheckInRequest request, CancellationToken ct)
    {
        if (!IsValidLocation(request.Latitude, request.Longitude))
            return BadRequest(new { error = "Toa do GPS khong hop le." });
        if (request.AccuracyMeters is not null &&
            (!double.IsFinite(request.AccuracyMeters.Value) || request.AccuracyMeters is <= 0 or > Domain.Booking.CheckInRadiusMeters))
            return BadRequest(new { error = "Do chinh xac GPS phai nam trong khoang 1-50m de check-in." });

        if (currentUser.UserId is not { } userId) return Unauthorized();
        var booking = await db.Bookings.SingleOrDefaultAsync(x => x.Id == id, ct);
        if (booking is null) return NotFound();
        if (booking.CaregiverId is not { } caregiverId)
            return BadRequest(new { error = "Booking chua co caregiver." });
        if (!await people.IsCaregiverForBookingAsync(caregiverId, userId, ct))
            return Forbid();

        var addressLocation = await catalog.GetAddressLocationAsync(booking.AddressId, ct);
        if (addressLocation is null)
            return BadRequest(new { error = "Khong tim thay toa do dia chi." });

        var caregiverGeo = new GeoPoint(request.Latitude, request.Longitude);
        var addressGeo = new GeoPoint(addressLocation.Value.Lat, addressLocation.Value.Lng);

        var oldStatus = BookingStatusCodec.ToApi(booking.Status);
        var result = booking.CheckIn(caregiverGeo, addressGeo);
        if (result.IsFailure) return Problem(result.Error);

        db.GpsTracks.Add(GpsTrack.Create(booking.Id, caregiverId,
            request.Latitude, request.Longitude, request.AccuracyMeters));

        double distance = caregiverGeo.DistanceMetersTo(addressGeo);
        string eventType = distance <= Domain.Booking.CheckInRadiusMeters
            ? "CHECKIN_VALID" : "CHECKIN_OUTSIDE_GEOFENCE";
        db.TimelineEvents.Add(CareTimelineEvent.Create(
            booking.Id, caregiverId, eventType, "Caregiver da check-in",
            latitude: request.Latitude, longitude: request.Longitude,
            distanceToAddressMeters: distance));

        await db.SaveChangesAsync(ct);
        await hub.Clients.Group(CareTrackingHub.BookingGroup(id))
            .SendAsync("BookingStatusChanged", new BookingStatusChangedEvent(
                id, oldStatus, BookingStatusCodec.ToApi(booking.Status), DateTimeOffset.UtcNow), ct);
        await NotifyBookingUserAsync(booking.CustomerId, booking, "Caregiver đã check-in",
            "Ca chăm sóc đã bắt đầu.", ct);
        return Ok(await ToResponseAsync(booking, ct));
    }

    private static bool IsValidLocation(double latitude, double longitude) =>
        double.IsFinite(latitude) && double.IsFinite(longitude) &&
        latitude is >= -90 and <= 90 && longitude is >= -180 and <= 180;

    /// <summary>Caregiver gửi yêu cầu checkout thủ công (khi chưa auto-checkout).</summary>
    [HttpPost("{id:guid}/checkout/request")]
    public async Task<IActionResult> RequestCheckout(Guid id, CancellationToken ct)
    {
        if (currentUser.UserId is not { } userId) return Unauthorized();
        var booking = await db.Bookings.SingleOrDefaultAsync(x => x.Id == id, ct);
        if (booking is null) return NotFound();
        if (booking.CaregiverId is not { } caregiverId)
            return BadRequest(new { error = "Booking chua co caregiver." });
        if (!await people.IsCaregiverForBookingAsync(caregiverId, userId, ct))
            return Forbid();

        var oldStatus = BookingStatusCodec.ToApi(booking.Status);
        var result = booking.RequestManualCheckout();
        if (result.IsFailure) return Problem(result.Error);
        db.TimelineEvents.Add(CareTimelineEvent.Create(
            booking.Id, caregiverId, "CHECKOUT_MANUAL_REQUESTED", "Yeu cau checkout thu cong"));
        await db.SaveChangesAsync(ct);
        await hub.Clients.Group(CareTrackingHub.BookingGroup(id))
            .SendAsync("BookingStatusChanged", new BookingStatusChangedEvent(
                id, oldStatus, BookingStatusCodec.ToApi(booking.Status), DateTimeOffset.UtcNow), ct);
        await NotifyBookingUserAsync(booking.CustomerId, booking, "Caregiver yêu cầu checkout",
            "Vui lòng kiểm tra và xác nhận hoàn tất ca chăm sóc.", ct);
        return Ok(await ToResponseAsync(booking, ct));
    }

    /// <summary>
    /// Customer/Admin xác nhận checkout rồi mới hoàn tất ca và giải ngân escrow.
    /// Caregiver chỉ được yêu cầu checkout qua /checkout/request.
    /// </summary>
    [HttpPost("{id:guid}/complete")]
    public async Task<IActionResult> Complete(Guid id, CancellationToken ct)
    {
        if (currentUser.UserId is not { } userId) return Unauthorized();
        var booking = await db.Bookings.SingleOrDefaultAsync(x => x.Id == id, ct);
        if (booking is null) return NotFound();
        if (booking.CaregiverId is not { } caregiverId)
            return BadRequest(new { error = "Booking chua co caregiver." });

        bool isCustomerApprover = booking.CustomerId == userId;
        bool isAdmin = currentUser.IsInRole("ADMIN");
        if (!isCustomerApprover && !isAdmin)
            return Forbid();
        if (booking.Status != BookingStatus.CheckoutPendingReview)
            return Conflict(new { error = "Chi co the hoan tat ca tu trang thai checkout_pending_review." });
        if (await disputeLookup.HasOpenDisputeAsync(booking.Id, ct))
            return Conflict(new { error = "Booking dang co dispute mo, khong the giai ngan tu dong." });

        var oldStatus = BookingStatusCodec.ToApi(booking.Status);
        var result = booking.Complete();
        if (result.IsFailure) return Problem(result.Error);

        var settleResult = await wallet.SettleAsync(booking.Id, caregiverId,
            booking.EscrowAmount, booking.PlatformFeeAmount, ct);
        if (settleResult.IsFailure) return Problem(settleResult.Error);

        db.TimelineEvents.Add(CareTimelineEvent.Create(
            booking.Id, caregiverId, "CHECKOUT", "Ca cham soc hoan thanh"));
        await db.SaveChangesAsync(ct);
        await hub.Clients.Group(CareTrackingHub.BookingGroup(id))
            .SendAsync("BookingStatusChanged", new BookingStatusChangedEvent(
                id, oldStatus, BookingStatusCodec.ToApi(booking.Status), DateTimeOffset.UtcNow), ct);
        await NotifyBookingUserAsync(booking.CustomerId, booking, "Ca chăm sóc đã hoàn tất",
            "Lịch chăm sóc đã được xác nhận hoàn tất.", ct);
        await NotifyCaregiverAsync(booking, "Ca chăm sóc đã hoàn tất",
            "Escrow đã được xử lý cho ca chăm sóc này.", ct);
        return Ok(await ToResponseAsync(booking, ct));
    }

    /// <summary>
    /// Kích hoạt SOS khẩn cấp trong ca chăm sóc.
    /// Cả Customer và Caregiver được assign đều có thể bấm SOS. Admin cũng được phép.
    /// </summary>
    [HttpPost("{id:guid}/sos")]
    public async Task<IActionResult> RaiseSos(Guid id, CancellationToken ct)
    {
        if (currentUser.UserId is not { } userId) return Unauthorized();
        var booking = await db.Bookings.SingleOrDefaultAsync(x => x.Id == id, ct);
        if (booking is null) return NotFound();

        bool isCustomer = booking.CustomerId == userId;
        bool isAdmin = currentUser.IsInRole("ADMIN");
        bool isAssignedCaregiver = booking.CaregiverId.HasValue
            && await people.IsCaregiverForBookingAsync(booking.CaregiverId.Value, userId, ct);

        if (!isCustomer && !isAssignedCaregiver && !isAdmin)
            return Forbid();

        var oldStatus = BookingStatusCodec.ToApi(booking.Status);
        var result = booking.RaiseSos(userId);
        if (result.IsFailure) return Problem(result.Error);

        db.TimelineEvents.Add(CareTimelineEvent.Create(
            booking.Id, booking.CaregiverId, "SOS",
            "Cấp cứu / tình huống khẩn cấp", note: $"SOS raised by user {userId}"));
        await db.SaveChangesAsync(ct);
        await hub.Clients.Group(CareTrackingHub.BookingGroup(id))
            .SendAsync("BookingStatusChanged", new BookingStatusChangedEvent(
                id, oldStatus, BookingStatusCodec.ToApi(booking.Status), DateTimeOffset.UtcNow), ct);
        await NotifySosTargetsAsync(booking, userId, ct);
        return Ok(await ToResponseAsync(booking, ct));
    }

    // ── Helpers ──

    private Task NotifyBookingUserAsync(Guid userId, Domain.Booking booking,
        string title, string body, CancellationToken ct) =>
        notifications.NotifyAsync(new UserNotificationMessage(
            userId,
            "BOOKING",
            title,
            body,
            BookingNotificationData(booking)), ct);

    private async Task NotifyCaregiverAsync(Domain.Booking booking,
        string title, string body, CancellationToken ct)
    {
        if (booking.CaregiverId is not { } caregiverId)
            return;

        var caregiverUserId = await people.GetUserIdByCaregiverProfileIdAsync(caregiverId, ct);
        if (caregiverUserId is null)
            return;

        await NotifyBookingUserAsync(caregiverUserId.Value, booking, title, body, ct);
    }

    private async Task NotifySosTargetsAsync(Domain.Booking booking, Guid raisedByUserId,
        CancellationToken ct)
    {
        var targets = new HashSet<Guid>();
        if (booking.CustomerId != raisedByUserId)
            targets.Add(booking.CustomerId);

        if (booking.CaregiverId is { } caregiverId)
        {
            var caregiverUserId = await people.GetUserIdByCaregiverProfileIdAsync(caregiverId, ct);
            if (caregiverUserId is not null && caregiverUserId.Value != raisedByUserId)
                targets.Add(caregiverUserId.Value);
        }

        foreach (var targetUserId in targets)
        {
            await notifications.NotifyAsync(new UserNotificationMessage(
                targetUserId,
                "SOS",
                "Có tín hiệu SOS",
                "Một tình huống khẩn cấp vừa được kích hoạt trong ca chăm sóc.",
                BookingNotificationData(booking)), ct);
        }
    }

    private Task<bool> HasCaregiverScheduleConflictAsync(Guid bookingId, Guid caregiverId,
        DateTimeOffset scheduledStart, DateTimeOffset scheduledEnd, CancellationToken ct) =>
        db.Bookings.AsNoTracking().AnyAsync(x =>
            x.Id != bookingId &&
            x.CaregiverId == caregiverId &&
            x.Status != BookingStatus.Completed &&
            x.Status != BookingStatus.Cancelled &&
            x.Status != BookingStatus.Refunded &&
            x.Status != BookingStatus.MatchingFailed &&
            x.ScheduledStart < scheduledEnd &&
            x.ScheduledEnd > scheduledStart, ct);

    private static IReadOnlyDictionary<string, string> BookingNotificationData(Domain.Booking booking) =>
        new Dictionary<string, string>
        {
            ["bookingId"] = booking.Id.ToString(),
            ["status"] = BookingStatusCodec.ToApi(booking.Status),
            ["deepLink"] = $"/bookings/{booking.Id}"
        };

    private async Task<IReadOnlyList<BookingResponse>> ToResponsesAsync(
        IReadOnlyList<Domain.Booking> bookings, CancellationToken ct)
    {
        var responses = new List<BookingResponse>(bookings.Count);
        foreach (var booking in bookings)
            responses.Add(await ToResponseAsync(booking, ct));
        return responses;
    }

    private async Task<BookingResponse> ToResponseAsync(Domain.Booking x, CancellationToken ct)
    {
        var beneficiary = await people.GetBeneficiaryDisplayAsync(x.BeneficiaryId, ct);
        var caregiver = x.CaregiverId is { } caregiverId
            ? await people.GetCaregiverDisplayAsync(caregiverId, ct)
            : null;
        var address = await catalog.GetAddressDisplayAsync(x.AddressId, ct);
        var service = await catalog.GetServiceDisplayAsync(x.ServiceTypeId, ct);

        return new BookingResponse(x.Id, x.BeneficiaryId,
            x.CaregiverId, x.AddressId, x.ServiceTypeId, x.ScheduledStart, x.ScheduledEnd,
            x.ActualStart, x.ActualEnd, x.CheckoutPendingReviewAt, x.CheckoutSource?.ToString(),
            BookingStatusCodec.ToApi(x.Status), x.EscrowAmount, x.PlatformFeeAmount,
            x.CancelledAt, x.CancelReason, x.CreatedAt, x.UpdatedAt,
            beneficiary?.DisplayName, caregiver?.DisplayName, address?.FullAddress, service?.Name,
            beneficiary?.Notes,
            beneficiary?.Age,
            beneficiary?.Relationship,
            beneficiary?.Condition,
            beneficiary?.Notes);
    }

    private static CaregiverSuggestionResponse ToCaregiverSuggestion(
        MatchingCandidate candidate,
        PeopleDisplaySummary? display)
    {
        candidate.ScoreBreakdown.TryGetValue("travelTimeMinutes", out var travelTimeMinutes);
        return new CaregiverSuggestionResponse(
            candidate.CaregiverId,
            display?.DisplayName,
            candidate.Rank,
            candidate.Score,
            candidate.DistanceMeters,
            travelTimeMinutes == 0m ? null : travelTimeMinutes,
            candidate.ScoreBreakdown);
    }

    private IActionResult Problem(Error error) => error.Type switch
    {
        ErrorType.NotFound => NotFound(new ProblemDetails { Title = error.Code, Detail = error.Message }),
        ErrorType.Conflict => Conflict(new ProblemDetails { Title = error.Code, Detail = error.Message }),
        ErrorType.Forbidden => Forbid(),
        _ => BadRequest(new ProblemDetails { Title = error.Code, Detail = error.Message })
    };
}

// ── DTOs ──
public sealed record CancelBookingRequest(string? Reason);
public sealed record RescheduleBookingRequest(DateTimeOffset ScheduledStart, DateTimeOffset ScheduledEnd);
public sealed record SelectCaregiverRequest(Guid CaregiverId);
public sealed record CheckInRequest(double Latitude, double Longitude, double? AccuracyMeters = null);

public sealed record CaregiverSuggestionResponse(
    Guid CaregiverId,
    string? DisplayName,
    int Rank,
    decimal Score,
    int? DistanceMeters,
    decimal? TravelTimeMinutes,
    IReadOnlyDictionary<string, decimal> ScoreBreakdown);

public sealed record BookingResponse(Guid Id, Guid BeneficiaryId, Guid? CaregiverId,
    Guid AddressId, Guid ServiceTypeId, DateTimeOffset ScheduledStart, DateTimeOffset ScheduledEnd,
    DateTimeOffset? ActualStart, DateTimeOffset? ActualEnd,
    DateTimeOffset? CheckoutPendingReviewAt, string? CheckoutSource,
    string Status, long EscrowAmount, long PlatformFeeAmount,
    DateTimeOffset? CancelledAt, string? CancelReason,
    DateTimeOffset CreatedAt, DateTimeOffset UpdatedAt,
    string? BeneficiaryName = null,
    string? CaregiverName = null,
    string? AddressText = null,
    string? ServiceName = null,
    string? Note = null,
    int? BeneficiaryAge = null,
    string? BeneficiaryRelationship = null,
    string? BeneficiaryCondition = null,
    string? BeneficiaryNotes = null);
