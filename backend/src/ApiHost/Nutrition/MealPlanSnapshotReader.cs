using System.Text.Json;
using CareSitter.Contracts.Nutrition;
using CareSitter.Nutrition.Grpc.V1;
using CareSitter.SharedKernel.Results;

namespace CareSitter.ApiHost.Nutrition;

internal sealed class MealPlanSnapshotReader(INutritionGateway gateway) : IMealPlanSnapshotReader
{
    public async Task<Result<MealPlanSnapshot>> ReadAsync(Guid beneficiaryId, Guid planId, CancellationToken ct)
        => await ReadCoreAsync(beneficiaryId, planId, false, ct);
    public async Task<Result<MealPlanSnapshot>> ReadForFeedbackAsync(Guid beneficiaryId, Guid planId, CancellationToken ct)
        => await ReadCoreAsync(beneficiaryId, planId, true, ct);
    private async Task<Result<MealPlanSnapshot>> ReadCoreAsync(Guid beneficiaryId, Guid planId, bool history, CancellationToken ct)
    {
        var result = await gateway.ReadAsync(new ResourceRequest
        {
            Kind = ResourceKind.Plan, BeneficiaryId = beneficiaryId.ToString(), ResourceId = planId.ToString()
        }, ct);
        if (result.StatusCode != 200 || result.Body is not NutritionResourceResponse resource)
            return result.StatusCode switch
            {
                401 => Error.Unauthorized("booking.meals.unauthenticated", "Vui lòng đăng nhập lại."),
                403 => Error.Forbidden("booking.meals.forbidden", "Không có quyền chia sẻ thực đơn này."),
                404 => Error.NotFound("booking.meals.plan_not_found", "Không tìm thấy thực đơn đã lưu."),
                _ => Error.Unavailable("booking.meals.nutrition_unavailable", "Chưa tải được thực đơn. Vui lòng thử lại.")
            };
        if (resource.Id != planId || resource.BeneficiaryId != beneficiaryId ||
            (resource.Status != "saved" && !(history && resource.Status == "stale")))
            return Error.Conflict("booking.meals.plan_stale", "Thực đơn cần được kiểm tra lại trước khi chia sẻ cho ca chăm sóc.");
        try
        {
            var payload = resource.Data.Deserialize<SnapshotPayload>(new JsonSerializerOptions(JsonSerializerDefaults.Web));
            if (payload is null || payload.PlannedDate == default || payload.Meals is not { Length: > 0 and <= 3 } ||
                payload.Meals.Any(x => x is null) ||
                payload.Meals.Select(x => x.MealType).Distinct().Count() != payload.Meals.Length ||
                payload.Meals.Select(x => x.VersionId).Distinct().Count() != payload.Meals.Length ||
                payload.Meals.Any(x => x.VersionId == Guid.Empty || string.IsNullOrWhiteSpace(x.Name) ||
                    x.MealType is not ("breakfast" or "lunch" or "dinner") || x.Servings <= 0 ||
                    x.Ingredients is null || x.PreparationSteps is null || x.Allergens is null))
                return Invalid();
            return new MealPlanSnapshot(planId, beneficiaryId, payload.PlannedDate, payload.Meals, resource.HealthRevision);
        }
        catch (JsonException) { return Invalid(); }
    }

    private static Error Invalid() => Error.Unavailable("booking.meals.invalid_plan", "Dữ liệu thực đơn chưa hợp lệ để chia sẻ.");
    private sealed record SnapshotPayload(DateOnly PlannedDate, SharedMeal[] Meals);
}
