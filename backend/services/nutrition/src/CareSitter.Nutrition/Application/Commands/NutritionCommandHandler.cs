using System.Security.Cryptography;
using System.Text;
using CareSitter.Nutrition.Contracts;
using CareSitter.Nutrition.Domain;
using CareSitter.Nutrition.Primitives;
using MediatR;

namespace CareSitter.Nutrition.Application;

internal sealed class NutritionCommandHandler(IPeopleHealthClient access, INutritionStore store,
    ICurrentUser user, INutritionFeatures features) : IRequestHandler<NutritionCommand, Result<ResourceResponse>>
{
    private const int DailyAssessmentLimit = 20;
    public async Task<Result<ResourceResponse>> Handle(NutritionCommand request, CancellationToken ct)
    {
        if (NutritionAccessRules.Check(user, features, true) is { } error) return error;
        if (request.ExpectedHealthRevision < 1 || request.IdempotencyKey == Guid.Empty)
            return Error.Validation("nutrition.request", "Phiên bản hồ sơ và khóa thao tác là bắt buộc.");
        if (request.Operation != "assess" && request.Operation != "confirm" && !features.RecommendationsEnabled)
            return Error.Unavailable("nutrition.recommendations_disabled", "Gợi ý thực đơn chưa được mở.");
        var observation = await access.ReadAsync(user.UserId!.Value, request.BeneficiaryId, ct);
        if (observation is null) return NutritionAccessRules.Missing();
        if (observation.Revision != request.ExpectedHealthRevision) return NutritionAccessRules.Changed();
        var result = await store.InOwnerScopeAsync<Result<ResourceResponse>>(user.UserId.Value, async session =>
        {
            var snapshot = observation;
            if (request.Operation == "confirm") return await ConfirmAsync(session, request, snapshot, ct);
            var kind = request.Operation switch { "assess" => "assessment", "recommend" or "replace" => "recommendation", "save" => "plan", _ => "" };
            if (kind.Length == 0) return Error.Validation("nutrition.operation", "Thao tác không hợp lệ.");
            var fingerprint = Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(NutritionJson.Write(request))));
            var existing = await session.FindByKeyAsync(kind, request.IdempotencyKey, ct);
            if (existing is not null)
            {
                if (existing.Fingerprint != fingerprint)
                    return Error.Conflict("nutrition.idempotency_conflict", "Khóa thao tác đã được dùng cho nội dung khác.");
                var mapped = ResourceMapping.Map(existing, snapshot.Revision);
                if (kind != "assessment" || existing.Status is not ("queued" or "processing"))
                {
                    var revision = kind == "assessment" ? NutritionJson.Read<AssessmentPayload>(existing.Payload).CatalogRevision
                        : NutritionJson.Read<MealPayload>(existing.Payload).CatalogRevision;
                    if (revision != await session.CatalogRevisionAsync(ct)) mapped = mapped with { Status = "stale" };
                }
                return mapped;
            }
            string payload, status;
            if (kind == "assessment")
            {
                if (await session.AssessmentCountAsync(ct) >= DailyAssessmentLimit) return Error.RateLimited("nutrition.quota", "Đã đạt giới hạn phân tích trong 24 giờ. Vui lòng thử lại sau.");
                if (new[] { snapshot.GeneralNote, snapshot.CareInstructions, snapshot.MobilityNote }.Any(s => s?.Length > 4000) || NutritionJson.Write(snapshot).Length > 16000)
                    return Error.Validation("nutrition.health_length", "Thông tin sức khỏe vượt giới hạn phân tích.");
                payload = NutritionJson.Write(new AssessmentPayload(1, snapshot, [], NutritionDecision.Create("queued", [])));
                status = "queued";
            }
            else
            {
                var mealResult = await BuildMealAsync(session, request, snapshot, ct);
                if (mealResult.IsFailure) return mealResult.Error;
                var meal = mealResult.Value;
                payload = NutritionJson.Write(meal); status = kind == "plan" ? "saved" : meal.Decision.State;
            }
            var resource = new NutritionResource(Guid.NewGuid(), user.UserId.Value, request.BeneficiaryId, snapshot.Revision, status, payload, request.IdempotencyKey, fingerprint, DateTimeOffset.UtcNow);
            await session.InsertAsync(kind, resource, ct);
            return ResourceMapping.Map(resource, snapshot.Revision);
        }, ct);
        // Hai DB độc lập: kết quả gắn revision, đọc lại nguồn sau commit; mọi lần dùng cũng revalidate.
        // Không hứa transaction nguyên tử xuyên service.
        if (result.IsSuccess)
        {
            var current = await access.ReadAsync(user.UserId.Value, request.BeneficiaryId, ct);
            if (current is null) return NutritionAccessRules.Missing();
            if (current.Revision != observation.Revision) return NutritionAccessRules.Changed();
        }
        return result;
    }

    private static async Task<Result<ResourceResponse>> ConfirmAsync(INutritionSession session, NutritionCommand request, BeneficiaryHealthSnapshot snapshot, CancellationToken ct)
    {
        var resource = await session.GetAsync("assessment", request.BeneficiaryId, request.ResourceId ?? Guid.Empty, ct);
        if (resource is null) return NutritionAccessRules.Missing();
        if (resource.HealthRevision != snapshot.Revision) return NutritionAccessRules.Changed();
        var payload = NutritionJson.Read<AssessmentPayload>(resource.Payload);
        if (payload.CatalogRevision != await session.CatalogRevisionAsync(ct)) return NutritionAccessRules.ContentChanged();
        if (resource.Status == "confirmed") return ResourceMapping.Map(resource, snapshot.Revision);
        if (resource.Status != "awaiting_confirmation") return Error.Conflict("nutrition.not_confirmable", "Bản phân tích chưa đủ điều kiện xác nhận.");
        var health = HealthSnapshotNormalizer.Normalize(snapshot, await session.ConceptsAsync(ct));
        var decision = NutritionEligibilityPolicy.Evaluate(snapshot, health, payload.Facts, await session.RulesAsync(ct), true);
        if (decision.State != "eligible") return Error.Conflict("nutrition.not_eligible", "Cần kiểm tra lại điều kiện và thông tin sức khỏe.");
        resource = resource with { Status = "confirmed", Payload = NutritionJson.Write(payload with { Decision = decision, ConfirmedAt = DateTimeOffset.UtcNow }) };
        await session.UpdateAsync("assessment", resource, null, ct);
        return ResourceMapping.Map(resource, snapshot.Revision);
    }

    private static async Task<Result<MealPayload>> BuildMealAsync(INutritionSession session, NutritionCommand request, BeneficiaryHealthSnapshot snapshot, CancellationToken ct)
    {
        MealPayload? previous = null;
        if (request.Operation is "replace" or "save")
        {
            var baseResource = await session.GetAsync("recommendation", request.BeneficiaryId, request.ResourceId ?? Guid.Empty, ct);
            if (baseResource is null) return NutritionAccessRules.Missing();
            if (baseResource.HealthRevision != snapshot.Revision) return NutritionAccessRules.Changed();
            previous = NutritionJson.Read<MealPayload>(baseResource.Payload);
            if (previous.Decision.State != "suggested") return Error.Conflict("nutrition.not_suggested", "Chưa có thực đơn để đổi hoặc lưu.");
        }
        var assessment = await session.GetAsync("assessment", request.BeneficiaryId, previous?.AssessmentId ?? request.AssessmentId ?? Guid.Empty, ct);
        if (assessment is null) return NutritionAccessRules.Missing();
        if (assessment.HealthRevision != snapshot.Revision) return NutritionAccessRules.Changed();
        if (assessment.Status != "confirmed") return Error.Conflict("nutrition.not_confirmed", "Vui lòng xác nhận thông tin trước khi xem gợi ý.");
        var analyzed = NutritionJson.Read<AssessmentPayload>(assessment.Payload);
        var catalogRevision = await session.CatalogRevisionAsync(ct);
        if (analyzed.CatalogRevision != catalogRevision) return NutritionAccessRules.ContentChanged();
        var rules = await session.RulesAsync(ct); var recipes = (await session.RecipesAsync(ct)).Where(MealConstraintPolicy.ValidRecipe).ToArray();
        var health = HealthSnapshotNormalizer.Normalize(snapshot, await session.ConceptsAsync(ct));
        var eligibility = NutritionEligibilityPolicy.Evaluate(snapshot, health, analyzed.Facts, rules, true);
        var date = previous?.PlannedDate ?? request.PlannedDate ?? DateOnly.FromDateTime(DateTime.UtcNow.AddHours(7));
        if (eligibility.State != "eligible") return new MealPayload(1, assessment.Id, date, [], [], eligibility);
        var activeRules = rules.Where(r => analyzed.Facts.Any(f => f.Kind == "condition" && f.Assertion == "present" && f.Temporality == "current" && f.Code == r.ConditionCode)).Select(r => r.VersionId).Order().ToArray();
        if (previous is not null && (previous.CatalogRevision != catalogRevision || !ContentCurrent(previous, recipes, rules) || !previous.AppliedRules.Order().SequenceEqual(activeRules))) return NutritionAccessRules.ContentChanged();
        Recipe[]? meals;
        if (request.Operation == "save") meals = previous!.Meals;
        else if (request.Operation == "replace")
        {
            var replacement = recipes.FirstOrDefault(r => r.VersionId == request.RecipeVersionId && r.MealType == request.MealType);
            if (replacement is null) return NutritionAccessRules.ContentChanged();
            meals = previous!.Meals.Select(m => m.MealType == request.MealType ? replacement : m).ToArray();
            if (!MealConstraintPolicy.Matches(meals, analyzed.Facts, rules)) return Error.Conflict("nutrition.constraint", "Món thay thế không đáp ứng các yêu cầu của toàn bộ thực đơn.");
        }
        else meals = MealConstraintPolicy.Choose(recipes, analyzed.Facts, rules);
        var decision = NutritionDecision.Create(meals is not null ? "suggested" : recipes.Length == 0 ? "no_content" : "no_match", meals is not null ? [] : [recipes.Length == 0 ? "catalog_unavailable" : "constraints_not_matched"]);
        return new MealPayload(1, assessment.Id, date, meals ?? [], activeRules, decision, catalogRevision);
    }

    internal static bool ContentCurrent(MealPayload payload, IReadOnlyList<Recipe> recipes, IReadOnlyList<DietaryRule> rules) =>
        payload.Meals.All(m => recipes.Any(r => r.VersionId == m.VersionId && NutritionJson.Write(r) == NutritionJson.Write(m))) &&
        payload.AppliedRules.All(id => rules.Any(r => r.VersionId == id && NutritionEligibilityPolicy.ValidRule(r)));
}
