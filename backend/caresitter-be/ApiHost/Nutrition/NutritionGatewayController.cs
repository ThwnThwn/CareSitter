using System.Globalization;
using CareSitter.Nutrition.Grpc.V1;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace CareSitter.ApiHost.Nutrition;

[ApiController, Authorize(Roles = "CUSTOMER"), RequestSizeLimit(32768)]
[Route("api/v1/beneficiaries/{beneficiaryId:guid}")]
public sealed class NutritionGatewayController(INutritionGateway gateway) : ControllerBase
{
    [HttpGet("/api/v1/nutrition/capabilities")]
    public async Task<IActionResult> Capabilities(CancellationToken ct) => Present(await gateway.CapabilitiesAsync(ct));

    [HttpPost("nutrition-assessments")]
    public async Task<IActionResult> Assess(Guid beneficiaryId, NutritionWriteRequest request, CancellationToken ct) =>
        Present(await gateway.ExecuteAsync(Command(CommandOperation.Assess, beneficiaryId, request), ct));
    [HttpGet("nutrition-assessments/{id:guid}")]
    public async Task<IActionResult> Assessment(Guid beneficiaryId, Guid id, CancellationToken ct) =>
        Present(await gateway.ReadAsync(Read(ResourceKind.Assessment, beneficiaryId, id), ct));
    [HttpPost("nutrition-assessments/{id:guid}/confirm")]
    public async Task<IActionResult> Confirm(Guid beneficiaryId, Guid id, NutritionWriteRequest request, CancellationToken ct) =>
        Present(await gateway.ExecuteAsync(Command(CommandOperation.Confirm, beneficiaryId, request, id), ct));
    [HttpPost("meal-recommendations")]
    public async Task<IActionResult> Recommend(Guid beneficiaryId, NutritionWriteRequest request, CancellationToken ct) =>
        Present(await gateway.ExecuteAsync(Command(CommandOperation.Recommend, beneficiaryId, request), ct));
    [HttpGet("meal-recommendations/{id:guid}")]
    public async Task<IActionResult> Recommendation(Guid beneficiaryId, Guid id, CancellationToken ct) =>
        Present(await gateway.ReadAsync(Read(ResourceKind.Recommendation, beneficiaryId, id), ct));
    [HttpPost("meal-recommendations/{id:guid}/replacements")]
    public async Task<IActionResult> Replace(Guid beneficiaryId, Guid id, NutritionWriteRequest request, CancellationToken ct) =>
        Present(await gateway.ExecuteAsync(Command(CommandOperation.Replace, beneficiaryId, request, id), ct));
    [HttpGet("meal-recommendations/{id:guid}/replacement-options")]
    public async Task<IActionResult> Replacements(Guid beneficiaryId, Guid id, [FromQuery] string mealType, CancellationToken ct) =>
        Present(await gateway.ReplacementsAsync(new ReplacementOptionsRequest
        { BeneficiaryId = beneficiaryId.ToString(), RecommendationId = id.ToString(), MealType = mealType }, ct));
    [HttpPost("meal-plans")]
    public async Task<IActionResult> Save(Guid beneficiaryId, NutritionWriteRequest request, CancellationToken ct) =>
        Present(await gateway.ExecuteAsync(Command(CommandOperation.Save, beneficiaryId, request, request.RecommendationId), ct));
    [HttpGet("meal-plans/{id:guid}")]
    public async Task<IActionResult> Plan(Guid beneficiaryId, Guid id, CancellationToken ct) =>
        Present(await gateway.ReadAsync(Read(ResourceKind.Plan, beneficiaryId, id), ct));
    [HttpGet("meal-plans")]
    public async Task<IActionResult> Plans(Guid beneficiaryId, CancellationToken ct) =>
        Present(await gateway.PlansAsync(new BeneficiaryRequest { BeneficiaryId = beneficiaryId.ToString() }, ct));

    private static CommandRequest Command(CommandOperation operation, Guid beneficiary, NutritionWriteRequest request, Guid? id = null)
    {
        var result = new CommandRequest
        {
            Operation = operation, BeneficiaryId = beneficiary.ToString(),
            ExpectedHealthRevision = request.ExpectedHealthRevision, IdempotencyKey = request.IdempotencyKey.ToString()
        };
        if (id.HasValue) result.ResourceId = id.Value.ToString();
        if (request.AssessmentId.HasValue) result.AssessmentId = request.AssessmentId.Value.ToString();
        if (request.PlannedDate.HasValue) result.PlannedDate = request.PlannedDate.Value.ToString("yyyy-MM-dd", CultureInfo.InvariantCulture);
        if (request.RecipeVersionId.HasValue) result.RecipeVersionId = request.RecipeVersionId.Value.ToString();
        if (request.MealType is not null) result.MealType = request.MealType;
        return result;
    }

    private static ResourceRequest Read(ResourceKind kind, Guid beneficiary, Guid id) =>
        new() { Kind = kind, BeneficiaryId = beneficiary.ToString(), ResourceId = id.ToString() };

    private IActionResult Present(NutritionGatewayResponse result)
    {
        if (result.StatusCode == 202 && result.Body is NutritionResourceResponse resource)
        {
            // Keep the public polling URL on ApiHost rather than exposing the internal RPC endpoint.
            return Accepted($"/api/v1/beneficiaries/{resource.BeneficiaryId}/nutrition-assessments/{resource.Id}", resource);
        }
        return StatusCode(result.StatusCode, result.Body);
    }
}
