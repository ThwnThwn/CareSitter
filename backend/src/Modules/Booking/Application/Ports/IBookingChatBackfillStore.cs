namespace CareSitter.Modules.Booking.Application;

/// <summary>Kết quả một lượt backfill/đối soát chat.</summary>
public sealed record BookingChatBackfillResult(
    int Examined,
    int ConversationsCreated,
    int ReconcileFlagsRaised,
    bool HasMore);

internal interface IBookingChatBackfillStore
{
    /// <summary>
    /// Tạo conversation/epoch còn thiếu cho booking đã nhận ca từ trước khi bật tính năng.
    /// Không tạo giả lịch sử nhận ca/check-in; chỉ thêm mốc "chat được kích hoạt".
    /// </summary>
    Task<BookingChatBackfillResult> BackfillMissingConversationsAsync(
        int batchSize, CancellationToken ct = default);

    /// <summary>
    /// Đếm booking lẽ ra đã có conversation nhưng đang thiếu, để job đối soát xử lý tiếp.
    /// Trả về số booking còn thiếu sau lượt chạy này.
    /// </summary>
    Task<int> CountMissingConversationsAsync(CancellationToken ct = default);
}
