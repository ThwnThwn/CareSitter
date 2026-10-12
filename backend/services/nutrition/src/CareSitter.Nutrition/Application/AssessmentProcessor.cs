using CareSitter.Nutrition.Contracts;
using CareSitter.Nutrition.Domain;

namespace CareSitter.Nutrition.Application;

public sealed class AssessmentProcessor(IPeopleHealthClient people, INutritionStore store, IHealthDescriptionParser parser)
{
    public async Task ProcessAsync((Guid Owner, Guid Beneficiary, Guid Id, Guid Token, int Attempts) job, CancellationToken ct)
    {
        var source = await people.ReadAsync(job.Owner, job.Beneficiary, ct);
        var input = await store.InOwnerScopeAsync<(NutritionResource Resource, IReadOnlyList<NutritionConcept> Concepts, IReadOnlyList<DietaryRule> Rules, long CatalogRevision)?>(job.Owner, async session =>
        {
            var resource = await session.GetAsync("assessment", job.Beneficiary, job.Id, ct);
            if (resource is null) return null;
            if (resource.Status is not ("queued" or "processing")) return null;
            var status = source is null ? "cancelled" : source.Revision != resource.HealthRevision ? "stale" : job.Attempts > 3 ? "failed" : "processing";
            var value = resource with { Status = status };
            if (status == "failed")
            {
                var payload = NutritionJson.Read<AssessmentPayload>(value.Payload);
                value = value with { Payload = NutritionJson.Write(payload with { ErrorCode = "nutrition.attempts_exhausted", Decision = NutritionDecision.Create("failed", ["attempts_exhausted"]) }) };
            }
            if (!await session.UpdateAsync("assessment", value, job.Token, ct) || status != "processing") return null;
            var catalogRevision = await session.CatalogRevisionAsync(ct);
            return (Resource: value, Concepts: await session.ConceptsAsync(ct), Rules: await session.RulesAsync(ct), CatalogRevision: catalogRevision);
        }, ct);
        if (input is null || source is null) return;
        var health = HealthSnapshotNormalizer.Normalize(source, input.Value.Concepts);
        var facts = health.Facts.ToList(); string? errorCode = null; var retryable = false;
        try
        {
            if (health.TextSources.Count > 0)
            {
                using var timeout = CancellationTokenSource.CreateLinkedTokenSource(ct);
                timeout.CancelAfter(TimeSpan.FromSeconds(25));
                var extracted = await parser.ParseAsync(health.TextSources, timeout.Token);
                if (!HealthSnapshotNormalizer.ValidateParserFacts(extracted, health.TextSources, input.Value.Concepts))
                    throw new HealthParserException("nutrition.ai_invalid_output", false);
                facts.AddRange(extracted);
            }
        }
        catch (OperationCanceledException) when (!ct.IsCancellationRequested) { errorCode = "nutrition.ai_timeout"; retryable = true; }
        catch (HealthParserException e) { errorCode = e.Code; retryable = e.Retryable; }
        var decision = errorCode is null ? NutritionEligibilityPolicy.Evaluate(source, health, facts, input.Value.Rules, false) : NutritionDecision.Create("failed", [errorCode]);
        var current = await people.ReadAsync(job.Owner, job.Beneficiary, ct);
        var status = current is null ? "cancelled" : current.Revision != source.Revision ? "stale" : decision.State;
        var completed = input.Value.Resource with { Status = status, Payload = NutritionJson.Write(new AssessmentPayload(1, source, facts.ToArray(), decision, errorCode, retryable, CatalogRevision: input.Value.CatalogRevision)) };
        await store.InOwnerScopeAsync(job.Owner, session => session.UpdateAsync("assessment", completed, job.Token, ct), ct);
    }
}
