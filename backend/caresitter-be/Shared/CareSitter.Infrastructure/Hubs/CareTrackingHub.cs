using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.SignalR;
using Microsoft.Extensions.DependencyInjection;

namespace CareSitter.Infrastructure.Hubs;

/// <summary>
/// SignalR Hub cho real-time GPS tracking, booking status updates và delta sync danh sách booking.
///
/// Groups được quản lý:
///   - booking-{bookingId} : tracking chi tiết GPS/timeline của 1 ca (join qua JoinBookingGroup)
///   - customer-{userId}   : delta sync danh sách booking (tự động join khi connect nếu là CUSTOMER)
///
/// URL: ws://localhost:5033/hubs/care-tracking
/// Auth: JWT Bearer token (query string: ?access_token=xxx hoặc Header Authorization)
/// </summary>
[Authorize]
public sealed class CareTrackingHub : Hub
{
    private readonly IServiceScopeFactory _scopeFactory;

    public CareTrackingHub(IServiceScopeFactory scopeFactory)
    {
        _scopeFactory = scopeFactory;
    }

    /// <summary>
    /// Khi customer kết nối, tự động thêm vào customer group để nhận BookingListSync event.
    /// Không cần client gọi hub method — server tự join dựa vào JWT claim.
    /// </summary>
    public override async Task OnConnectedAsync()
    {
        await base.OnConnectedAsync();

        var userId = GetUserId();
        if (userId.HasValue && IsCustomer())
        {
            await Groups.AddToGroupAsync(Context.ConnectionId, CustomerGroup(userId.Value));
        }
    }

    /// <summary>
    /// Client gọi để join vào group theo dõi booking cụ thể (tracking GPS/timeline).
    /// Yêu cầu: caller phải là CustomerId hoặc CaregiverId của booking.
    /// Trả về "ok" nếu thành công, "unauthorized" hoặc error string nếu không có quyền.
    /// </summary>
    public async Task<string> JoinBookingGroup(string bookingId)
    {
        if (!Guid.TryParse(bookingId, out var bookingGuid))
            return "invalid_booking_id";

        var userId = GetUserId();
        if (!userId.HasValue)
            return "unauthorized";

        await using var scope = _scopeFactory.CreateAsyncScope();
        var checker = scope.ServiceProvider.GetService<IBookingMembershipChecker>();

        if (checker is null)
        {
            Console.WriteLine("[CareTrackingHub] MISCONFIGURED: IBookingMembershipChecker not registered.");
            return "service_not_configured";
        }

        bool isMember = await checker.IsPartyToBookingAsync(bookingGuid, userId.Value);

        if (!isMember)
        {
            Console.WriteLine(
                $"[CareTrackingHub] BLOCKED join: user={userId.Value} booking={bookingGuid}");
            return "unauthorized";
        }

        await Groups.AddToGroupAsync(Context.ConnectionId, BookingGroup(bookingId));
        return "ok";
    }

    /// <summary>Client gọi để rời group khi thoát màn hình tracking.</summary>
    public async Task LeaveBookingGroup(string bookingId)
    {
        await Groups.RemoveFromGroupAsync(Context.ConnectionId, BookingGroup(bookingId));
    }

    /// <summary>Tên group theo booking ID — dùng cho tracking chi tiết GPS/timeline.</summary>
    public static string BookingGroup(string bookingId) => $"booking-{bookingId}";
    public static string BookingGroup(Guid bookingId) => $"booking-{bookingId:D}";

    /// <summary>Tên group theo customer user ID — dùng cho delta sync danh sách booking.</summary>
    public static string CustomerGroup(Guid customerId) => $"customer-{customerId:D}";
    public static string CustomerGroup(string customerId) => $"customer-{customerId}";

    // ── Private helpers ──────────────────────────────────────────────────────

    private Guid? GetUserId()
    {
        var userIdStr = Context.User?
            .FindFirst(System.Security.Claims.ClaimTypes.NameIdentifier)?.Value
            ?? Context.User?.FindFirst("sub")?.Value;
        return Guid.TryParse(userIdStr, out var uid) ? uid : null;
    }

    private bool IsCustomer() =>
        Context.User?.IsInRole("CUSTOMER") == true;
}

/// <summary>
/// Interface cho service kiểm tra booking membership.
/// Khai báo ở Shared layer để Hub không phụ thuộc vào Booking module.
/// Implementation (BookingMembershipReader) được đăng ký từ Booking module.
/// </summary>
public interface IBookingMembershipChecker
{
    Task<bool> IsPartyToBookingAsync(Guid bookingId, Guid userId, CancellationToken ct = default);
}

/// <summary>DTOs cho các sự kiện broadcast từ server → client.</summary>
public sealed record GpsUpdatedEvent(
    Guid BookingId,
    Guid CaregiverId,
    double Latitude,
    double Longitude,
    double? AccuracyMeters,
    double? Speed,
    double? Heading,
    DateTimeOffset RecordedAt);

/// <summary>Event broadcast tới booking-{id} group — tracking chi tiết trạng thái.</summary>
public sealed record BookingStatusChangedEvent(
    Guid BookingId,
    string OldStatus,
    string NewStatus,
    DateTimeOffset ChangedAt);

public sealed record TimelineEventAddedEvent(
    Guid BookingId,
    Guid? CaregiverId,
    string EventType,
    string? Title,
    string? Note,
    double? Latitude,
    double? Longitude,
    DateTimeOffset RecordedAt);

/// <summary>
/// Event broadcast tới customer-{customerId} group — tín hiệu để client gọi delta sync.
/// KHÔNG chứa full state booking để tránh partial update và schema drift.
/// Client nhận event này phải gọi GET /api/v1/bookings/sync?cursor={lastCursor}.
/// </summary>
public sealed record BookingListSyncEvent(
    Guid BookingId,
    long BookingVersion,
    long Cursor,
    DateTimeOffset ChangedAt);
