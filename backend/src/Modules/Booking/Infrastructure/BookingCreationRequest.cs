namespace CareSitter.Modules.Booking.Infrastructure;

internal sealed class BookingCreationRequest
{
    private BookingCreationRequest() { }

    private BookingCreationRequest(
        Guid customerId,
        Guid idempotencyKey,
        string payloadHash,
        Guid bookingId,
        DateTimeOffset createdAt)
    {
        CustomerId = customerId;
        IdempotencyKey = idempotencyKey;
        PayloadHash = payloadHash;
        BookingId = bookingId;
        CreatedAt = createdAt;
    }

    public Guid CustomerId { get; private set; }
    public Guid IdempotencyKey { get; private set; }
    public string PayloadHash { get; private set; } = string.Empty;
    public Guid BookingId { get; private set; }
    public DateTimeOffset CreatedAt { get; private set; }

    public static BookingCreationRequest Create(
        Guid customerId,
        Guid idempotencyKey,
        string payloadHash,
        Guid bookingId,
        DateTimeOffset createdAt) =>
        new(customerId, idempotencyKey, payloadHash, bookingId, createdAt);
}
