namespace CareSitter.Messaging.Contracts.Events;

/// <summary>References a saved selection; health facts and recipe contents stay in the owning service.</summary>
public sealed record MealPlanSelected(Guid BookingId, Guid MealSelectionId);
