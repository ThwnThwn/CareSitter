namespace CareSitter.Modules.Booking.Domain;

public sealed class BookingMealCorrection
{
    private BookingMealCorrection() { }
    public Guid Id { get; private set; }
    public Guid BookingId { get; private set; }
    public Guid RecordId { get; private set; }
    public int Revision { get; private set; }
    public string Outcome { get; private set; } = "";
    public string? Note { get; private set; }
    public string Reason { get; private set; } = "";
    public Guid CorrectedBy { get; private set; }
    public DateTimeOffset CorrectedAt { get; private set; }
    public Guid IdempotencyKey { get; private set; }
    public Guid TimelineEventId { get; private set; }
    public static BookingMealCorrection Create(Guid bookingId, Guid recordId, int revision,
        string outcome, string? note, string reason, Guid actor, DateTimeOffset now, Guid key, Guid timelineId) =>
        new() { Id = Guid.NewGuid(), BookingId = bookingId, RecordId = recordId, Revision = revision,
            Outcome = outcome, Note = note, Reason = reason, CorrectedBy = actor,
            CorrectedAt = now, IdempotencyKey = key, TimelineEventId = timelineId };
}
