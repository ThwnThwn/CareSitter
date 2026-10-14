using CareSitter.Nutrition.Application;
using CareSitter.Nutrition.Primitives;
using MediatR;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace CareSitter.Nutrition.Controllers;

[ApiController, Authorize(Roles = "CUSTOMER")]
[Route("api/v1/beneficiaries/{beneficiaryId:guid}")]
public sealed class NutritionController(IMediator mediator) : ControllerBase
{
    [HttpPost("nutrition-assessments")]
    public async Task<IActionResult> Assess(Guid beneficiaryId, NutritionWriteRequest request, CancellationToken ct) =>
        Present(await mediator.Send(new AssessNutritionCommand(beneficiaryId, Input(request)), ct), queued: true);
    [HttpGet("nutrition-assessments/{id:guid}")]
    public async Task<IActionResult> Assessment(Guid beneficiaryId, Guid id, CancellationToken ct) =>
        Present(await mediator.Send(new NutritionResourceQuery("assessment", beneficiaryId, id), ct));
    [HttpPost("nutrition-assessments/{id:guid}/confirm")]
    public async Task<IActionResult> Confirm(Guid beneficiaryId, Guid id, NutritionWriteRequest request, CancellationToken ct) =>
        Present(await mediator.Send(new ConfirmNutritionCommand(beneficiaryId, id, Input(request)), ct));
    [HttpPost("meal-recommendations")]
    public async Task<IActionResult> Recommend(Guid beneficiaryId, NutritionWriteRequest request, CancellationToken ct) =>
        Present(await mediator.Send(new RecommendMealsCommand(beneficiaryId, Input(request)), ct));
    [HttpGet("meal-recommendations/{id:guid}")]
    public async Task<IActionResult> Recommendation(Guid beneficiaryId, Guid id, CancellationToken ct) =>
        Present(await mediator.Send(new NutritionResourceQuery("recommendation", beneficiaryId, id), ct));
    [HttpPost("meal-recommendations/{id:guid}/replacements")]
    public async Task<IActionResult> Replace(Guid beneficiaryId, Guid id, NutritionWriteRequest request, CancellationToken ct) =>
        Present(await mediator.Send(new ReplaceMealCommand(beneficiaryId, id, Input(request)), ct));
    [HttpGet("meal-recommendations/{id:guid}/replacement-options")]
    public async Task<IActionResult> ReplacementOptions(Guid beneficiaryId, Guid id, [FromQuery] string mealType, CancellationToken ct)
    {
        var result = await mediator.Send(new ReplacementOptionsQuery(beneficiaryId, id, mealType), ct);
        return result.IsSuccess ? Ok(result.Value) : Failure(result.Error);
    }
    [HttpPost("meal-plans")]
    public async Task<IActionResult> Save(Guid beneficiaryId, NutritionWriteRequest request, CancellationToken ct) =>
        Present(await mediator.Send(new SaveMealPlanCommand(beneficiaryId, request.RecommendationId ?? Guid.Empty, Input(request)), ct));
    [HttpGet("meal-plans/{id:guid}")]
    public async Task<IActionResult> Plan(Guid beneficiaryId, Guid id, CancellationToken ct) =>
        Present(await mediator.Send(new NutritionResourceQuery("plan", beneficiaryId, id), ct));
    [HttpGet("meal-plans")]
    public async Task<IActionResult> Plans(Guid beneficiaryId, CancellationToken ct)
    {
        var result = await mediator.Send(new ListMealPlansQuery(beneficiaryId), ct);
        return result.IsSuccess ? Ok(result.Value) : Failure(result.Error);
    }
    private static NutritionWriteInput Input(NutritionWriteRequest r) =>
        new(r.ExpectedHealthRevision, r.IdempotencyKey, r.AssessmentId, r.PlannedDate, r.RecipeVersionId, r.MealType);
    private IActionResult Present(Result<ResourceResponse> result, bool queued = false) => result.IsFailure ? Failure(result.Error) :
        queued ? Accepted($"/api/v1/beneficiaries/{result.Value.BeneficiaryId}/nutrition-assessments/{result.Value.Id}", result.Value) : Ok(result.Value);
    private IActionResult Failure(Error error) => StatusCode(error.Type switch
    {
        ErrorType.Unauthorized => 401,
        ErrorType.Forbidden => 403,
        ErrorType.NotFound => 404,
        ErrorType.Conflict => 409,
        ErrorType.Unavailable => 503,
        ErrorType.RateLimited => 429,
        _ => 400
    }, new ProblemDetails { Title = error.Code, Detail = error.Message });
}
