using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.SignalR;
using Microsoft.Extensions.DependencyInjection;

namespace CareSitter.Infrastructure.Hubs;

/// <summary>
/// SignalR Hub cho real-time GPS tracking và booking status updates.
///
/// Client kết nối → gọi JoinBookingGroup(bookingId) để lắng nghe sự kiện của booking đó.
/// Server broadcast tự động khi:
///   - Caregiver gửi GPS mới (GpsUpdated)
///   - Booking đổi trạng thái (BookingStatusChanged)
///   - Timeline event mới (TimelineEventAdded)
///
/// URL: ws://localhost:5033/hubs/care-tracking
/// Auth: JWT Bearer token (query string: ?access_token=xxx hoặc Header Authorization)
///
/// Authorization: JoinBookingGroup kiểm tra user phải là customer hoặc caregiver
/// được assign cho booking đó. User không liên quan sẽ nhận lỗi "unauthorized".
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
    /// Client gọi để join vào group theo dõi booking cụ thể.
    /// Yêu cầu: caller phải là CustomerId hoặc CaregiverId của booking.
    /// Trả về "ok" nếu thành công, "unauthorized" hoặc error string nếu không có quyền.
    /// </summary>
    public async Task<string> JoinBookingGroup(string bookingId)
    {
        if (!Guid.TryParse(bookingId, out var bookingGuid))
            return "invalid_booking_id";

        // Lấy userId từ JWT claim (sub hoặc NameIdentifier)
        var userIdStr = Context.User?
            .FindFirst(System.Security.Claims.ClaimTypes.NameIdentifier)?.Value
            ?? Context.User?.FindFirst("sub")?.Value;

        if (!Guid.TryParse(userIdStr, out var userId))
            return "unauthorized";

        // Verify membership qua DB (dùng scope riêng, không giữ connection)
        // Hub dùng IBookingMembershipChecker interface (từ Shared layer) để tránh
        // circular dependency với Booking module. Implementation được đăng ký từ Booking module.
        await using var scope = _scopeFactory.CreateAsyncScope();
        var checker = scope.ServiceProvider.GetService<IBookingMembershipChecker>();

        // Nếu service chưa được đăng ký → từ chối thay vì fallback trust JWT
        if (checker is null)
        {
            Console.WriteLine("[CareTrackingHub] MISCONFIGURED: IBookingMembershipChecker not registered.");
            return "service_not_configured";
        }

        bool isMember = await checker.IsPartyToBookingAsync(bookingGuid, userId);

        if (!isMember)
        {
            Console.WriteLine(
                $"[CareTrackingHub] BLOCKED join: user={userId} booking={bookingGuid}");
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

    /// <summary>Tên group theo booking ID.</summary>
    public static string BookingGroup(string bookingId) => $"booking-{bookingId}";
    public static string BookingGroup(Guid bookingId) => $"booking-{bookingId:D}";
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
