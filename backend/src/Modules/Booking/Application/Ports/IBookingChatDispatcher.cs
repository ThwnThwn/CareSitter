namespace CareSitter.Modules.Booking.Application;

/// <summary>
/// Đẩy signal chat đã commit trong outbox ra realtime/notification.
/// Signal chỉ báo "có thay đổi"; client tự tải delta qua REST.
/// </summary>
internal interface IBookingChatDispatcher
{
    /// <summary>Xử lý một lượt row đang chờ; trả về số row đã xử lý xong.</summary>
    Task<int> DispatchPendingAsync(int batchSize, CancellationToken ct = default);
}
