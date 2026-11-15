namespace CareSitter.Modules.Booking.Domain;

public sealed class BookingMealPlan
{
    private BookingMealPlan() { }
    public Guid Id { get; private set; }
    public Guid BookingId { get; private set; }
    public Guid PlanId { get; private set; }
    public DateOnly PlannedDate { get; private set; }
    public string MealsJson { get; private set; } = "[]";
    public long HealthRevision { get; private set; }
    public string? HealthFingerprint { get; private set; }
    public Guid SharedBy { get; private set; }
    public DateTimeOffset SharedAt { get; private set; }
    public DateTimeOffset? RevokedAt { get; private set; }

    public static BookingMealPlan Share(Guid bookingId, Guid planId, DateOnly date,
        string mealsJson, Guid sharedBy, DateTimeOffset now, long healthRevision = 0, string? healthFingerprint = null) => new()
    {
        Id = Guid.NewGuid(), BookingId = bookingId, PlanId = planId, PlannedDate = date,
        MealsJson = mealsJson, SharedBy = sharedBy, SharedAt = now, HealthRevision = healthRevision, HealthFingerprint = healthFingerprint
    };
    public void Revoke(DateTimeOffset now) => RevokedAt ??= now;
    public void Reshare(Guid planId, string mealsJson, Guid userId, DateTimeOffset now, long healthRevision = 0, string? healthFingerprint = null)
    {
        PlanId = planId; MealsJson = mealsJson; SharedBy = userId; SharedAt = now; RevokedAt = null; HealthRevision = healthRevision;
        HealthFingerprint = healthFingerprint;
    }
}
