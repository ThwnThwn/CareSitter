namespace CareSitter.Modules.Booking.Domain;

public sealed class BookingMealRecord
{
    private BookingMealRecord() { }
    public Guid Id { get; private set; }
    public Guid BookingId { get; private set; }
    public Guid PlanId { get; private set; }
    public DateOnly PlannedDate { get; private set; }
    public Guid RecipeVersionId { get; private set; }
    public string MealType { get; private set; } = "";
    public string Outcome { get; private set; } = "";
    public string? Note { get; private set; }
    public Guid RecordedBy { get; private set; }
    public DateTimeOffset RecordedAt { get; private set; }
    public Guid IdempotencyKey { get; private set; }
    public Guid TimelineEventId { get; private set; }

    public static BookingMealRecord Create(Guid bookingId, Guid planId, DateOnly date, Guid recipeId,
        string mealType, string outcome, string? note, Guid userId, DateTimeOffset now,
        Guid key, Guid timelineEventId) => new()
    {
        Id = Guid.NewGuid(), BookingId = bookingId, PlanId = planId, PlannedDate = date,
        RecipeVersionId = recipeId, MealType = mealType, Outcome = outcome, Note = note,
        RecordedBy = userId, RecordedAt = now, IdempotencyKey = key, TimelineEventId = timelineEventId
    };
}
