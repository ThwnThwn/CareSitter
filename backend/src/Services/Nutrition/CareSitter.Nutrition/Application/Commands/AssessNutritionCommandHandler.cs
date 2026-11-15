using CareSitter.Nutrition.Contracts;
using CareSitter.Nutrition.Domain;
using CareSitter.Nutrition.Primitives;
using MediatR;

namespace CareSitter.Nutrition.Application;

internal sealed class AssessNutritionCommandHandler(NutritionWriteScope scope)
    : IRequestHandler<AssessNutritionCommand, Result<ResourceResponse>>
{
    private const int DailyAssessmentLimit = 20;

    public Task<Result<ResourceResponse>> Handle(AssessNutritionCommand request, CancellationToken ct) =>
        scope.ExecuteAsync(request, false, (session, snapshot) =>
            scope.CreateAsync(session, request, snapshot, "assessment", () => QueueAsync(session, snapshot, ct), ct), ct);

    private static async Task<Result<NutritionResourceDraft>> QueueAsync(INutritionSession session,
        BeneficiaryHealthSnapshot snapshot, CancellationToken ct)
    {
        if (await session.AssessmentCountAsync(ct) >= DailyAssessmentLimit)
            return Error.RateLimited("nutrition.quota", "Đã đạt giới hạn phân tích trong 24 giờ. Vui lòng thử lại sau.");
        if (new[] { snapshot.GeneralNote, snapshot.CareInstructions, snapshot.MobilityNote }.Any(s => s?.Length > 4000)
            || NutritionJson.Write(snapshot).Length > 16000)
            return Error.Validation("nutrition.health_length", "Thông tin sức khỏe vượt giới hạn phân tích.");

        var payload = new AssessmentPayload(1, snapshot, [], NutritionDecision.Create("queued", []));
        return new NutritionResourceDraft("queued", NutritionJson.Write(payload));
    }
}
