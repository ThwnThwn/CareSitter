using System.Security.Cryptography;
using System.Text;

namespace CareSitter.Modules.Booking.Domain;

/// <summary>
/// Sinh <c>sourceEventId</c> ổn định cho system message của chat theo booking.
/// Cùng booking + cùng phiên bản mutation + cùng loại sự kiện luôn cho cùng ID,
/// nên retry hoặc job chạy lại không tạo thêm system message trùng.
/// </summary>
public static class BookingChatSourceEventIds
{
    /// <summary>Đánh dấu hội thoại được kích hoạt cho lịch đã có trước khi bật tính năng.</summary>
    public const string ChatBackfilled = "CHAT_BACKFILLED";

    /// <summary>
    /// ID dạng UUID v5-like: 16 byte đầu của SHA-256 với bit phiên bản/biến thể
    /// được đặt đúng chuẩn để cột <c>uuid</c> nhận giá trị hợp lệ.
    /// </summary>
    public static Guid Create(Guid bookingId, long bookingVersion, string eventType)
    {
        var input = Encoding.UTF8.GetBytes($"{bookingId:N}:{bookingVersion}:{eventType}");
        var hash = SHA256.HashData(input);
        Span<byte> bytes = stackalloc byte[16];
        hash.AsSpan(0, 16).CopyTo(bytes);
        bytes[7] = (byte)((bytes[7] & 0x0f) | 0x50);
        bytes[8] = (byte)((bytes[8] & 0x3f) | 0x80);
        return new Guid(bytes);
    }

    /// <summary>
    /// ID cho mục "chat được kích hoạt cho lịch này" khi backfill booking có trước
    /// tính năng. Backfill tự chống trùng bằng điều kiện "conversation chưa tồn tại";
    /// unique index theo conversation là lớp chặn thứ hai nếu hai lần chạy đua nhau.
    /// </summary>
    public static Guid CreateForBackfill(Guid bookingId, long bookingVersion) =>
        Create(bookingId, bookingVersion, ChatBackfilled);
}
