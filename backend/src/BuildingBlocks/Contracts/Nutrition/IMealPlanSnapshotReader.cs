using CareSitter.SharedKernel.Results;

namespace CareSitter.Contracts.Nutrition;

/// <summary>Chỉ đọc thực đơn đã lưu bằng quyền của khách hàng hiện tại; không chia sẻ hồ sơ sức khỏe.</summary>
public interface IMealPlanSnapshotReader
{
    Task<Result<MealPlanSnapshot>> ReadAsync(Guid beneficiaryId, Guid planId, CancellationToken ct);
    Task<Result<MealPlanSnapshot>> ReadForFeedbackAsync(Guid beneficiaryId, Guid planId, CancellationToken ct) =>
        ReadAsync(beneficiaryId, planId, ct);
}

public sealed record MealPlanSnapshot(Guid Id, Guid BeneficiaryId, DateOnly PlannedDate,
    IReadOnlyList<SharedMeal> Meals, long HealthRevision = 0);
public sealed record SharedMeal(Guid VersionId, string Name, string MealType, decimal Servings,
    IReadOnlyList<SharedMealIngredient> Ingredients, IReadOnlyList<string> PreparationSteps,
    IReadOnlyList<string> Allergens);
public sealed record SharedMealIngredient(string Name, decimal Amount, string Unit);
