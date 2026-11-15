using CareSitter.SharedKernel.Results;

namespace CareSitter.Modules.Booking.Application;

internal static class LiveTrackingErrors
{
    public static Error NotEnRoute() => Error.Conflict("booking.gps.not_en_route", "Ca không còn ở trạng thái đang di chuyển.");
    public static Error InvalidSession() => Error.Conflict("booking.gps.invalid_session", "Phiên chia sẻ vị trí đã hết hạn. Hãy mở lại phiên.");
    public static Error SourceActive() => Error.Conflict("booking.gps.source_active", "Ca này đang chia sẻ vị trí từ thiết bị khác.");
    public static Error TooFrequent() => Error.Conflict("booking.gps.rate_limited", "Vui lòng chờ trước khi gửi vị trí tiếp theo.");
    public static Error Unavailable() => Error.Unavailable("booking.gps.unavailable", "Chưa thể cập nhật vị trí. Vui lòng thử lại.");
}
