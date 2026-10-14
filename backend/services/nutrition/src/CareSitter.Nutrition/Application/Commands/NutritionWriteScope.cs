using CareSitter.Nutrition.Contracts;
using CareSitter.Nutrition.Domain;
using CareSitter.Nutrition.Primitives;

namespace CareSitter.Nutrition.Application;

internal sealed class NutritionWriteScope(IPeopleHealthClient access, INutritionStore store,
    ICurrentUser user, INutritionFeatures features)
{
    public async Task<Result<ResourceResponse>> ExecuteAsync(NutritionWriteCommand request,
        bool requiresRecommendations,
        Func<INutritionSession, BeneficiaryHealthSnapshot, Task<Result<ResourceResponse>>> action, CancellationToken ct)
    {
        if (NutritionAccessRules.Check(user, features, true) is { } error) return error;
        if (request.Input.ExpectedHealthRevision < 1 || request.IdempotencyKey == Guid.Empty)
            return Error.Validation("nutrition.request", "Phiên bản hồ sơ và khóa thao tác là bắt buộc.");
        if (requiresRecommendations && !features.RecommendationsEnabled)
            return Error.Unavailable("nutrition.recommendations_disabled", "Gợi ý thực đơn chưa được mở.");

        var owner = user.UserId!.Value;
        var observation = await access.ReadAsync(owner, request.BeneficiaryId, ct);
        if (observation is null) return NutritionAccessRules.Missing();
        if (observation.Revision != request.Input.ExpectedHealthRevision) return NutritionAccessRules.Changed();
        var result = await store.InOwnerScopeAsync(owner, session => action(session, observation), ct);
        // Separate databases: revalidate ownership/revision after commit and on every later read.
        if (result.IsSuccess)
        {
            var current = await access.ReadAsync(owner, request.BeneficiaryId, ct);
            if (current is null) return NutritionAccessRules.Missing();
            if (current.Revision != observation.Revision) return NutritionAccessRules.Changed();
        }
        return result;
    }

    public async Task<Result<ResourceResponse>> CreateAsync(INutritionSession session, NutritionWriteCommand request,
        BeneficiaryHealthSnapshot snapshot, string kind, Func<Task<Result<NutritionResourceDraft>>> create, CancellationToken ct)
    {
        var fingerprint = NutritionRequestFingerprint.For(request);
        var existing = await session.FindByKeyAsync(kind, request.IdempotencyKey, ct);
        if (existing is not null)
        {
            if (existing.Fingerprint != fingerprint)
                return Error.Conflict("nutrition.idempotency_conflict", "Khóa thao tác đã được dùng cho nội dung khác.");
            var mapped = ResourceMapping.Map(existing, snapshot.Revision);
            if (kind != "assessment" || existing.Status is not ("queued" or "processing"))
            {
                var revision = kind == "assessment"
                    ? NutritionJson.Read<AssessmentPayload>(existing.Payload).CatalogRevision
                    : NutritionJson.Read<MealPayload>(existing.Payload).CatalogRevision;
                if (revision != await session.CatalogRevisionAsync(ct)) mapped = mapped with { Status = "stale" };
            }
            return mapped;
        }

        var draft = await create();
        if (draft.IsFailure) return draft.Error;
        var resource = new NutritionResource(Guid.NewGuid(), user.UserId!.Value, request.BeneficiaryId,
            snapshot.Revision, draft.Value.Status, draft.Value.Payload, request.IdempotencyKey, fingerprint, DateTimeOffset.UtcNow);
        await session.InsertAsync(kind, resource, ct);
        return ResourceMapping.Map(resource, snapshot.Revision);
    }
}

internal sealed record NutritionResourceDraft(string Status, string Payload);
