using CareSitter.SharedKernel.Results;

namespace CareSitter.Modules.Promotion.Domain;

public static class PromotionErrors
{
    public static Error Unauthenticated() => Error.Unauthorized(
        "promotion.unauthenticated", "Vui lòng đăng nhập để sử dụng ưu đãi.");
    public static Error NotFound() => Error.NotFound(
        "promotion.not_found", "Không tìm thấy ưu đãi.");
    public static Error NotActive() => Error.Conflict(
        "promotion.not_active", "Ưu đãi chưa bắt đầu hoặc đã hết hạn.");
    public static Error ServiceNotEligible() => Error.Validation(
        "promotion.service_not_eligible", "Ưu đãi không áp dụng cho dịch vụ đã chọn.");
    public static Error FirstBookingOnly() => Error.Conflict(
        "promotion.first_booking_only", "Ưu đãi chỉ áp dụng cho đơn thanh toán đầu tiên.");
    public static Error UsageLimitReached() => Error.Conflict(
        "promotion.usage_limit_reached", "Ưu đãi đã hết lượt sử dụng.");
    public static Error CustomerUsageLimitReached() => Error.Conflict(
        "promotion.customer_usage_limit_reached", "Bạn đã sử dụng hết lượt của ưu đãi này.");
    public static Error MinimumOrderNotMet(long amount) => Error.Validation(
        "promotion.minimum_order_not_met", $"Giá trị đơn tối thiểu là {amount:N0}đ.");
    public static Error InvalidGrossAmount() => Error.Validation(
        "promotion.invalid_gross_amount", "Giá trị đơn hàng không hợp lệ.");
    public static Error ZeroPaymentNotSupported() => Error.Validation(
        "promotion.zero_payment_not_supported",
        "Ưu đãi không thể giảm toàn bộ giá trị đơn ở luồng thanh toán hiện tại.");
    public static Error InvalidDiscountConfiguration() => Error.Failure(
        "promotion.invalid_configuration", "Cấu hình ưu đãi không hợp lệ.");
    public static Error InvalidReservation() => Error.Validation(
        "promotion.invalid_reservation", "Thông tin giữ ưu đãi không hợp lệ.");
    public static Error ReservationExpired() => Error.Conflict(
        "promotion.reservation_expired", "Lượt giữ ưu đãi đã hết hạn.");
    public static Error AlreadyRedeemed() => Error.Conflict(
        "promotion.already_redeemed", "Ưu đãi đã được ghi nhận sử dụng.");
}
