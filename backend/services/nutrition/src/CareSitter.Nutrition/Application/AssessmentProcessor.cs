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
                value = value with { Payload = NutritionJson.Write(payload with
                {
                    ErrorCode = "nutrition.attempts_exhausted", Retryable = false,
                    Decision = NutritionDecision.Failure("nutrition.attempts_exhausted", false)
                }) };
            }
            if (!await session.UpdateAsync("assessment", value, job.Token, ct) || status != "processing") return null;
            var catalogRevision = await session.CatalogRevisionAsync(ct);
            return (Resource: value, Concepts: await session.ConceptsAsync(ct), Rules: await session.RulesAsync(ct), CatalogRevision: catalogRevision);
        }, ct);
        if (input is null || source is null) return;
        var health = HealthSnapshotNormalizer.Normalize(source, input.Value.Concepts);
        var facts = health.Facts.ToList(); string? errorCode = null; var retryable = false;
        HealthParseResult? validatedParserResult = null;
        try
        {
            if (health.TextSources.Count > 0)
            {
                using var timeout = CancellationTokenSource.CreateLinkedTokenSource(ct);
                timeout.CancelAfter(TimeSpan.FromSeconds(25));
                var graph = HealthKnowledgeGraphRetriever.Retrieve(input.Value.CatalogRevision, health.TextSources,
                    input.Value.Concepts, input.Value.Rules);
                var request = new HealthParseRequest(HealthParseResultValidator.SchemaVersion, input.Value.CatalogRevision,
                    health.TextSources, input.Value.Concepts, graph);
                var extracted = await parser.ParseAsync(request, timeout.Token);
                if (!HealthParseResultValidator.TryValidate(request, extracted, out var parsedFacts))
                    throw new HealthParserException("nutrition.ai_invalid_output", false);
                validatedParserResult = extracted;
                facts.AddRange(parsedFacts);
                health = health with
                {
                    Unresolved = health.Unresolved.Concat(HealthParseResultValidator.UnresolvedFields(extracted))
                        .Distinct(StringComparer.Ordinal).ToArray()
                };
            }
        }
        catch (OperationCanceledException) when (!ct.IsCancellationRequested) { errorCode = "nutrition.ai_timeout"; retryable = true; }
        catch (HealthParserException e) { errorCode = e.Code; retryable = e.Retryable; }
        var decision = errorCode is null ? NutritionEligibilityPolicy.Evaluate(source, health, facts, input.Value.Rules, false) : NutritionDecision.Failure(errorCode, retryable);
        decision = NutritionClarificationPolicy.Attach(decision, validatedParserResult?.UnresolvedStatements);
        var current = await people.ReadAsync(job.Owner, job.Beneficiary, ct);
        var status = current is null ? "cancelled" : current.Revision != source.Revision ? "stale" : decision.State;
        await store.InOwnerScopeAsync(job.Owner, async session =>
        {
            var finalDecision = decision; var finalError = errorCode; var finalRetryable = retryable;
            var currentCatalogRevision = await session.CatalogRevisionAsync(ct);
            if (status is not ("cancelled" or "stale") && currentCatalogRevision != input.Value.CatalogRevision)
            {
                status = "stale"; finalError = "nutrition.content_changed"; finalRetryable = false;
                finalDecision = NutritionDecision.Create("stale", ["catalog_changed"]);
            }
            var completed = input.Value.Resource with
            {
                Status = status,
                Payload = NutritionJson.Write(new AssessmentPayload(2, source, facts.ToArray(), finalDecision, finalError, finalRetryable,
                CatalogRevision: input.Value.CatalogRevision,
                ParserUnresolved: validatedParserResult?.UnresolvedStatements,
                IrrelevantSourceKeys: validatedParserResult?.IrrelevantSourceKeys,
                ParserSchemaVersion: validatedParserResult?.SchemaVersion,
                ParserDictionaryRevision: validatedParserResult?.DictionaryRevision,
                ParserPromptVersion: validatedParserResult is null ? null : parser.PromptVersion,
                ParserGraphSchemaVersion: validatedParserResult is null ? null : HealthKnowledgeGraphRetriever.SchemaVersion,
                ParserGraphRevision: validatedParserResult is null ? null : input.Value.CatalogRevision,
                ParserRetrievalStrategy: validatedParserResult is null ? null : HealthKnowledgeGraphRetriever.Strategy))
            };
            return await session.UpdateAsync("assessment", completed, job.Token, ct);
        }, ct);
    }
}
