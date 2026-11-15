namespace CareSitter.Modules.People.Domain;

public sealed class MealTasteFeedback
{
    private MealTasteFeedback() { }
    public Guid Id { get; private set; }
    public Guid OwnerId { get; private set; }
    public Guid BeneficiaryId { get; private set; }
    public Guid PlanId { get; private set; }
    public DateOnly PlannedDate { get; private set; }
    public Guid RecipeVersionId { get; private set; }
    public string MealType { get; private set; } = "";
    public string MealName { get; private set; } = "";
    public string Feedback { get; private set; } = "";
    public string Status { get; private set; } = "pending";
    public Guid SubmittedBy { get; private set; }
    public string SubmittedByRole { get; private set; } = "";
    public DateTimeOffset SubmittedAt { get; private set; }
    public Guid IdempotencyKey { get; private set; }
    public string Fingerprint { get; private set; } = "";
    public Guid? ReviewedBy { get; private set; }
    public DateTimeOffset? ReviewedAt { get; private set; }
    public long? AppliedHealthRevision { get; private set; }

    public static MealTasteFeedback Create(Guid owner, Guid beneficiary, Guid plan, DateOnly date,
        Guid recipe, string mealType, string name, string feedback, Guid actor, string role,
        Guid key, string fingerprint, DateTimeOffset now) => new()
        {
            Id = Guid.NewGuid(), OwnerId = owner, BeneficiaryId = beneficiary, PlanId = plan,
            PlannedDate = date, RecipeVersionId = recipe, MealType = mealType, MealName = name,
            Feedback = feedback, SubmittedBy = actor, SubmittedByRole = role, SubmittedAt = now,
            IdempotencyKey = key, Fingerprint = fingerprint
        };

    public void Review(bool approve, Guid actor, DateTimeOffset now, long? revision)
    {
        if (actor != OwnerId || Status != "pending") throw new InvalidOperationException("Invalid feedback review.");
        Status = approve ? "approved" : "rejected";
        ReviewedBy = actor;
        ReviewedAt = now;
        AppliedHealthRevision = approve ? revision : null;
    }
}
