using CareSitter.Nutrition.Grpc.V1;
using System.Text.Json;

namespace CareSitter.ApiHost.Nutrition;

public interface INutritionGateway
{
    Task<NutritionGatewayResponse> CapabilitiesAsync(CancellationToken ct);
    Task<NutritionGatewayResponse> ExecuteAsync(CommandRequest request, CancellationToken ct);
    Task<NutritionGatewayResponse> ReadAsync(ResourceRequest request, CancellationToken ct);
    Task<NutritionGatewayResponse> PlansAsync(BeneficiaryRequest request, CancellationToken ct);
    Task<NutritionGatewayResponse> ReplacementsAsync(ReplacementOptionsRequest request, CancellationToken ct);
}

public sealed record NutritionGatewayResponse(int StatusCode, object Body);
public sealed record NutritionResourceResponse(Guid Id, Guid BeneficiaryId, long HealthRevision,
    string Status, JsonElement Data, DateTimeOffset CreatedAt);
public sealed record NutritionWriteRequest(long ExpectedHealthRevision, Guid IdempotencyKey,
    Guid? AssessmentId = null, DateOnly? PlannedDate = null, Guid? RecommendationId = null,
    Guid? RecipeVersionId = null, string? MealType = null);
