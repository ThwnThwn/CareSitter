namespace CareSitter.Contracts.Services;

/// <summary>
/// Dữ liệu booking tối thiểu để Support xác thực quyền tạo review mà không phụ thuộc
/// trực tiếp vào BookingDbContext.
/// </summary>
public sealed record ReviewableBooking(
    Guid BookingId,
    Guid CustomerId,
    Guid? CaregiverId,
    bool IsCompleted);

public interface IReviewBookingLookup
{
    Task<ReviewableBooking?> GetForReviewAsync(
        Guid bookingId,
        CancellationToken ct = default);
}
