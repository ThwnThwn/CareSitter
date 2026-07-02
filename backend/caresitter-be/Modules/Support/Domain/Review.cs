using CareSitter.SharedKernel.Domain;
using CareSitter.SharedKernel.Results;

namespace CareSitter.Modules.Support.Domain;

/// <summary>
/// Danh gia cua khach cho 1 booking (1 review / booking). Map sang bang support.reviews.
/// Co created_at, KHONG co updated_at.
/// </summary>
public sealed class Review : Entity
{
    private Review() { } // EF

    private Review(
        Guid id,
        Guid bookingId,
        Guid caregiverId,
        Guid customerId,
        int rating,
        string? comment,
        string? experienceTags) : base(id)
    {
        BookingId = bookingId;
        CaregiverId = caregiverId;
        CustomerId = customerId;
        Rating = rating;
        Comment = comment;
        ExperienceTags = experienceTags;
    }

    public Guid BookingId { get; private set; }
    public Guid CaregiverId { get; private set; }
    public Guid CustomerId { get; private set; }

    public int Rating { get; private set; }
    public string? Comment { get; private set; }

    /// <summary>jsonb — vd ['Dung gio','Tan tam',...].</summary>
    public string? ExperienceTags { get; private set; }

    public static Result<Review> Create(
        Guid bookingId,
        Guid caregiverId,
        Guid customerId,
        int rating,
        string? comment = null,
        string? experienceTags = null)
    {
        if (bookingId == Guid.Empty)
            return Error.Validation("review.booking", "booking_id khong duoc rong.");
        if (caregiverId == Guid.Empty)
            return Error.Validation("review.caregiver", "caregiver_id khong duoc rong.");
        if (customerId == Guid.Empty)
            return Error.Validation("review.customer", "customer_id khong duoc rong.");
        if (rating is < 1 or > 5)
            return Error.Validation("review.rating", "rating phai trong khoang 1..5.");

        return new Review(Guid.NewGuid(), bookingId, caregiverId, customerId, rating, comment, experienceTags);
    }
}
