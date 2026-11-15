namespace CareSitter.Modules.People.Controllers;
public sealed record SubmitMealTasteFeedbackRequest(Guid PlanId, Guid RecipeVersionId, string Feedback);
