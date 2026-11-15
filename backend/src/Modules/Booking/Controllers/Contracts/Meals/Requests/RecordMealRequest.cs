namespace CareSitter.Modules.Booking.Controllers;

public sealed record RecordMealRequest(Guid PlanId, Guid RecipeVersionId, string MealType, string Outcome, string? Note);
