using CareSitter.Nutrition.Contracts;
using CareSitter.Nutrition.Primitives;
using MediatR;

namespace CareSitter.Nutrition.Application;

internal sealed class ConfirmNutritionCommandHandler(NutritionWriteScope scope)
    : IRequestHandler<ConfirmNutritionCommand, Result<ResourceResponse>>
{
    public Task<Result<ResourceResponse>> Handle(ConfirmNutritionCommand request, CancellationToken ct) =>
        scope.ExecuteAsync(request, false, (session, snapshot) => ConfirmAsync(session, request, snapshot, ct), ct);

    private static async Task<Result<ResourceResponse>> ConfirmAsync(INutritionSession session,
        ConfirmNutritionCommand request, BeneficiaryHealthSnapshot snapshot, CancellationToken ct)
    {
        var resource = await session.GetAsync("assessment", request.BeneficiaryId, request.AssessmentId, ct);
        if (resource is null) return NutritionAccessRules.Missing();
        if (resource.HealthRevision != snapshot.Revision) return NutritionAccessRules.Changed();
        var payload = NutritionJson.Read<AssessmentPayload>(resource.Payload);
        if (payload.CatalogRevision != await session.CatalogRevisionAsync(ct)) return NutritionAccessRules.ContentChanged();
        if (resource.Status == "confirmed") return ResourceMapping.Map(resource, snapshot.Revision);
        if (resource.Status != "awaiting_confirmation")
            return Error.Conflict("nutrition.not_confirmable", "Bản phân tích chưa đủ điều kiện xác nhận.");

        var health = HealthSnapshotNormalizer.Normalize(snapshot, await session.ConceptsAsync(ct));
        var decision = NutritionEligibilityPolicy.Evaluate(snapshot, health, payload.Facts, await session.RulesAsync(ct), true);
        if (decision.State != "eligible")
            return Error.Conflict("nutrition.not_eligible", "Cần kiểm tra lại điều kiện và thông tin sức khỏe.");
        resource = resource with
        {
            Status = "confirmed",
            Payload = NutritionJson.Write(payload with { Decision = decision, ConfirmedAt = DateTimeOffset.UtcNow })
        };
        await session.UpdateAsync("assessment", resource, null, ct);
        return ResourceMapping.Map(resource, snapshot.Revision);
    }
}
