using CareSitter.Nutrition.Contracts;
using CareSitter.Nutrition.Domain;

namespace CareSitter.Nutrition.Application.Evaluation;

public sealed record HealthParserEvaluationCorpus(int SchemaVersion, string CorpusVersion, long DictionaryRevision,
    NutritionConcept[] Concepts, DietaryRule[] Rules, HealthParserEvaluationCase[] Cases);

public sealed record HealthParserEvaluationCase(string Id, string RootScenarioId, string Split,
    bool ReleaseBlocking, string LabelReviewStatus, string[] Tags, BeneficiaryHealthSnapshot Snapshot,
    HealthParseResult Expected, string ExpectedDecision);

public sealed record HealthParserEvaluationRun(int SchemaVersion, string CorpusVersion, string Split,
    string Provider, string Model, string PromptVersion, long DictionaryRevision, int GraphSchemaVersion,
    string RetrievalStrategy, DateTimeOffset StartedAt, DateTimeOffset CompletedAt,
    HealthParserEvaluationRunCase[] Cases);

public sealed record HealthParserEvaluationRunCase(string CaseId, HealthParseResult? Output, string? ErrorCode,
    long LatencyMilliseconds, long InputTokens, long OutputTokens);

public sealed record HealthParserCorpusValidation(bool IsValid, int CaseCount, int ReviewedCaseCount,
    IReadOnlyDictionary<string, int> SplitCounts, string[] Issues);

public sealed record HealthParserFactMetric(int Expected, int Actual, int Matched, double Precision, double Recall);

public sealed record HealthParserEvaluationReport(bool CorpusValid, string CorpusVersion, string Split,
    int ExpectedCases, int EvaluatedCases, int ValidOutputCases, int ExactCases, int ReviewedCases,
    int ExpectedFacts, int ActualFacts, int MatchedFacts, double FactPrecision, double FactRecall,
    double ProvenanceValidityRate, double DecisionAccuracy, long P50LatencyMilliseconds,
    long P95LatencyMilliseconds, long InputTokens, long OutputTokens,
    IReadOnlyDictionary<string, HealthParserFactMetric> FactKindMetrics,
    IReadOnlyDictionary<string, double> TagExactMatchRates, string[] FailedCaseIds,
    string[] CriticalFailureIds, string[] Issues, bool TechnicalGatePassed, bool ReleaseGatePassed);

public static class HealthParserEvaluation
{
    public const int SchemaVersion = 1;
    public const int MinimumCases = 200;
    private static readonly IReadOnlySet<string> Splits = new HashSet<string>(StringComparer.Ordinal)
        { "development", "validation", "holdout" };
    private static readonly IReadOnlySet<string> ReviewStates = new HashSet<string>(StringComparer.Ordinal)
        { "pending", "reviewed" };
    private static readonly IReadOnlySet<string> Decisions = new HashSet<string>(StringComparer.Ordinal)
    {
        "awaiting_confirmation", "needs_information", "needs_professional_guidance", "failed"
    };
    private static readonly string[] RequiredTags =
    [
        "with_diacritics", "without_diacritics", "abbreviation", "negation", "uncertainty", "history",
        "multiple_subjects", "food_allergy", "drug_allergy", "preference", "medication_unknown",
        "dietary_instruction", "harmless", "repeated_quote", "prompt_injection", "unknown_concept",
        "multiple_sources"
    ];

    public static HealthParserCorpusValidation Validate(HealthParserEvaluationCorpus? corpus)
    {
        var issues = new List<string>();
        if (corpus is null)
            return new(false, 0, 0, new Dictionary<string, int>(), ["corpus.required"]);
        if (corpus.SchemaVersion != SchemaVersion) issues.Add("corpus.schema_version");
        if (string.IsNullOrWhiteSpace(corpus.CorpusVersion) || corpus.CorpusVersion.Length > 100)
            issues.Add("corpus.version");
        if (corpus.DictionaryRevision < 0) issues.Add("corpus.dictionary_revision");
        var concepts = (corpus.Concepts ?? []).Where(concept => concept is not null).ToArray();
        var rules = (corpus.Rules ?? []).Where(rule => rule is not null).ToArray();
        var sourceCases = corpus.Cases ?? [];
        var cases = sourceCases.Where(item => item is not null).ToArray();
        if (concepts.Length != (corpus.Concepts?.Length ?? 0) || concepts.Length is 0 or > 2000 ||
            concepts.Any(concept => string.IsNullOrWhiteSpace(concept.Kind) || string.IsNullOrWhiteSpace(concept.Code) ||
                concept.Version <= 0 || concept.Aliases is not { Length: > 0 } ||
                concept.Aliases.Any(string.IsNullOrWhiteSpace)) ||
            concepts.Select(concept => $"{concept.Kind}\u001f{concept.Code}")
                .Distinct(StringComparer.Ordinal).Count() != concepts.Length)
            issues.Add("corpus.concepts");
        if (rules.Length != (corpus.Rules?.Length ?? 0) || rules.Any(rule => !NutritionEligibilityPolicy.ValidRule(rule)))
            issues.Add("corpus.rules");
        if (sourceCases.Length is < MinimumCases or > 1000) issues.Add("corpus.case_count");
        if (cases.Length != sourceCases.Length || cases.Select(item => item.Id).Distinct(StringComparer.Ordinal).Count() != cases.Length)
            issues.Add("corpus.case_ids");

        var splitCounts = cases.Where(item => Splits.Contains(item.Split))
            .GroupBy(item => item.Split, StringComparer.Ordinal)
            .ToDictionary(group => group.Key, group => group.Count(), StringComparer.Ordinal);
        if (GetCount(splitCounts, "development") < 80 || GetCount(splitCounts, "validation") < 40 ||
            GetCount(splitCounts, "holdout") < 40) issues.Add("corpus.split_counts");
        if (cases.GroupBy(item => item.RootScenarioId, StringComparer.Ordinal)
            .Any(group => group.Select(item => item.Split).Distinct(StringComparer.Ordinal).Count() != 1))
            issues.Add("corpus.root_scenario_split_leakage");

        var tags = cases.Where(item => item.Tags is not null).SelectMany(item => item.Tags)
            .ToHashSet(StringComparer.Ordinal);
        foreach (var required in RequiredTags) if (!tags.Contains(required)) issues.Add($"corpus.missing_tag:{required}");

        foreach (var item in cases) ValidateCase(corpus, item, concepts, rules, issues);
        var reviewed = cases.Count(item => item.LabelReviewStatus == "reviewed");
        return new(issues.Count == 0, sourceCases.Length, reviewed, splitCounts, issues.Distinct(StringComparer.Ordinal).ToArray());
    }

    public static HealthParseRequest CreateRequest(HealthParserEvaluationCorpus corpus, HealthParserEvaluationCase item)
    {
        var health = HealthSnapshotNormalizer.Normalize(item.Snapshot, corpus.Concepts);
        var graph = HealthKnowledgeGraphRetriever.Retrieve(corpus.DictionaryRevision, health.TextSources,
            corpus.Concepts, corpus.Rules);
        return new(HealthParseResultValidator.SchemaVersion, corpus.DictionaryRevision, health.TextSources,
            corpus.Concepts, graph);
    }

    public static string ExpectedDecision(HealthParserEvaluationCorpus corpus, HealthParserEvaluationCase item)
    {
        var request = CreateRequest(corpus, item);
        if (!HealthParseResultValidator.TryValidate(request, item.Expected, out var facts))
            throw new ArgumentException("Expected parser output does not satisfy the parser contract.", nameof(item));
        return EvaluateDecision(item, corpus.Concepts, corpus.Rules, facts, item.Expected);
    }

    public static HealthParserEvaluationReport Score(HealthParserEvaluationCorpus corpus, HealthParserEvaluationRun run)
    {
        var validation = Validate(corpus);
        var issues = validation.Issues.ToList();
        if (run.SchemaVersion != SchemaVersion) issues.Add("run.schema_version");
        if (run.CorpusVersion != corpus.CorpusVersion) issues.Add("run.corpus_version");
        if (!Splits.Contains(run.Split)) issues.Add("run.split");
        if (run.DictionaryRevision != corpus.DictionaryRevision) issues.Add("run.dictionary_revision");
        if (string.IsNullOrWhiteSpace(run.Provider) || run.Provider.Length > 100 ||
            string.IsNullOrWhiteSpace(run.Model) || run.Model.Length > 100 ||
            string.IsNullOrWhiteSpace(run.PromptVersion) || run.PromptVersion.Length > 100)
            issues.Add("run.provider_metadata");
        if (run.GraphSchemaVersion != HealthKnowledgeGraphRetriever.SchemaVersion ||
            run.RetrievalStrategy != HealthKnowledgeGraphRetriever.Strategy) issues.Add("run.graph_version");
        if (run.StartedAt == default || run.CompletedAt == default || run.CompletedAt < run.StartedAt)
            issues.Add("run.timestamps");

        if (!validation.IsValid)
            return EmptyReport(corpus, run, validation, issues);

        var selected = corpus.Cases.Where(item => item.Split == run.Split).OrderBy(item => item.Id, StringComparer.Ordinal).ToArray();
        var runCases = run.Cases ?? [];
        if (runCases.Any(item => item is null) || runCases.Select(item => item.CaseId)
                .Distinct(StringComparer.Ordinal).Count() != runCases.Length) issues.Add("run.case_ids");
        var byId = runCases.Where(item => item is not null).GroupBy(item => item.CaseId, StringComparer.Ordinal)
            .ToDictionary(group => group.Key, group => group.First(), StringComparer.Ordinal);
        if (byId.Keys.Any(id => selected.All(item => item.Id != id))) issues.Add("run.unexpected_cases");

        var failed = new List<string>(); var critical = new List<string>();
        var expectedFacts = 0; var actualFacts = 0; var matchedFacts = 0;
        var validOutputs = 0; var exactCases = 0; var decisionMatches = 0; var provenanceValid = 0;
        var expectedByKind = new Dictionary<string, int>(StringComparer.Ordinal);
        var actualByKind = new Dictionary<string, int>(StringComparer.Ordinal);
        var matchedByKind = new Dictionary<string, int>(StringComparer.Ordinal);
        var tagTotals = selected.SelectMany(item => item.Tags).GroupBy(tag => tag, StringComparer.Ordinal)
            .ToDictionary(group => group.Key, group => group.Count(), StringComparer.Ordinal);
        var tagMatches = new Dictionary<string, int>(StringComparer.Ordinal);
        foreach (var expectedCase in selected)
        {
            expectedFacts += expectedCase.Expected.Facts.Length;
            CountKinds(expectedCase.Expected.Facts, expectedByKind);
            if (!byId.TryGetValue(expectedCase.Id, out var actualCase))
            {
                failed.Add(expectedCase.Id); if (expectedCase.ReleaseBlocking) critical.Add(expectedCase.Id); continue;
            }
            if (actualCase.LatencyMilliseconds < 0 || actualCase.InputTokens < 0 || actualCase.OutputTokens < 0)
                issues.Add($"run.metrics:{expectedCase.Id}");
            if (actualCase.Output is null || !string.IsNullOrWhiteSpace(actualCase.ErrorCode))
            {
                failed.Add(expectedCase.Id); if (expectedCase.ReleaseBlocking) critical.Add(expectedCase.Id); continue;
            }
            actualFacts += actualCase.Output.Facts?.Length ?? 0;
            CountKinds(actualCase.Output.Facts ?? [], actualByKind);
            var request = CreateRequest(corpus, expectedCase);
            var valid = HealthParseResultValidator.TryValidate(request, actualCase.Output, out var parsedFacts);
            if (valid) { validOutputs++; provenanceValid++; }
            var expectedFactIds = expectedCase.Expected.Facts.Select(FactIdentity).ToHashSet(StringComparer.Ordinal);
            var actualFactIds = (actualCase.Output.Facts ?? []).Select(FactIdentity).ToHashSet(StringComparer.Ordinal);
            matchedFacts += expectedFactIds.Intersect(actualFactIds, StringComparer.Ordinal).Count();
            foreach (var fact in expectedCase.Expected.Facts.Where(fact => actualFactIds.Contains(FactIdentity(fact))))
                Increment(matchedByKind, fact.Kind);
            var factsExact = expectedFactIds.SetEquals(actualFactIds);
            var unresolvedExact = expectedCase.Expected.UnresolvedStatements.Select(UnresolvedIdentity)
                .ToHashSet(StringComparer.Ordinal).SetEquals((actualCase.Output.UnresolvedStatements ?? [])
                    .Select(UnresolvedIdentity));
            var irrelevantExact = expectedCase.Expected.IrrelevantSourceKeys.ToHashSet(StringComparer.Ordinal)
                .SetEquals(actualCase.Output.IrrelevantSourceKeys ?? []);
            var actualDecision = valid ? EvaluateDecision(expectedCase, corpus.Concepts, corpus.Rules, parsedFacts,
                actualCase.Output) : "failed";
            var decisionExact = actualDecision == expectedCase.ExpectedDecision;
            if (decisionExact) decisionMatches++;
            var exact = valid && factsExact && unresolvedExact && irrelevantExact && decisionExact;
            if (exact)
            {
                exactCases++;
                foreach (var tag in expectedCase.Tags) Increment(tagMatches, tag);
            }
            else { failed.Add(expectedCase.Id); if (expectedCase.ReleaseBlocking) critical.Add(expectedCase.Id); }
        }

        var latencies = runCases.Where(item => item is not null && item.LatencyMilliseconds >= 0)
            .Select(item => item.LatencyMilliseconds).Order().ToArray();
        var reviewed = selected.Count(item => item.LabelReviewStatus == "reviewed");
        var structuralIssues = issues.Distinct(StringComparer.Ordinal).ToArray();
        var factKindMetrics = expectedByKind.Keys.Concat(actualByKind.Keys).Distinct(StringComparer.Ordinal)
            .Order(StringComparer.Ordinal).ToDictionary(kind => kind, kind =>
            {
                var expected = GetCount(expectedByKind, kind);
                var actual = GetCount(actualByKind, kind);
                var matched = GetCount(matchedByKind, kind);
                return new HealthParserFactMetric(expected, actual, matched, Ratio(matched, actual), Ratio(matched, expected));
            }, StringComparer.Ordinal);
        var tagRates = tagTotals.OrderBy(pair => pair.Key, StringComparer.Ordinal).ToDictionary(pair => pair.Key,
            pair => Ratio(GetCount(tagMatches, pair.Key), pair.Value), StringComparer.Ordinal);
        var technicalGate = validation.IsValid && structuralIssues.Length == 0 && selected.Length > 0 &&
            byId.Count == selected.Length && exactCases == selected.Length && critical.Count == 0;
        var releaseGate = technicalGate && run.Split == "holdout" && reviewed == selected.Length;
        return new(validation.IsValid, corpus.CorpusVersion, run.Split, selected.Length, byId.Count, validOutputs,
            exactCases, reviewed, expectedFacts, actualFacts, matchedFacts, Ratio(matchedFacts, actualFacts),
            Ratio(matchedFacts, expectedFacts), Ratio(provenanceValid, selected.Length),
            Ratio(decisionMatches, selected.Length), Percentile(latencies, 0.50), Percentile(latencies, 0.95),
            runCases.Sum(item => item?.InputTokens ?? 0), runCases.Sum(item => item?.OutputTokens ?? 0),
            factKindMetrics, tagRates,
            failed.Distinct(StringComparer.Ordinal).Order(StringComparer.Ordinal).ToArray(),
            critical.Distinct(StringComparer.Ordinal).Order(StringComparer.Ordinal).ToArray(), structuralIssues,
            technicalGate, releaseGate);
    }

    private static HealthParserEvaluationReport EmptyReport(HealthParserEvaluationCorpus corpus,
        HealthParserEvaluationRun run, HealthParserCorpusValidation validation, IEnumerable<string> issues) =>
        new(false, corpus.CorpusVersion ?? string.Empty, run.Split ?? string.Empty, 0, 0, 0, 0,
            validation.ReviewedCaseCount, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            new Dictionary<string, HealthParserFactMetric>(), new Dictionary<string, double>(), [], [],
            issues.Distinct(StringComparer.Ordinal).ToArray(), false, false);

    private static void ValidateCase(HealthParserEvaluationCorpus corpus, HealthParserEvaluationCase item,
        IReadOnlyList<NutritionConcept> concepts, IReadOnlyList<DietaryRule> rules, ICollection<string> issues)
    {
        if (string.IsNullOrWhiteSpace(item.Id) || item.Id.Length > 100 || string.IsNullOrWhiteSpace(item.RootScenarioId) ||
            item.RootScenarioId.Length > 100) issues.Add($"case.identity:{item.Id}");
        if (!Splits.Contains(item.Split)) issues.Add($"case.split:{item.Id}");
        if (!ReviewStates.Contains(item.LabelReviewStatus)) issues.Add($"case.review_status:{item.Id}");
        if (item.Tags is null || item.Tags.Length == 0 || item.Tags.Any(string.IsNullOrWhiteSpace))
            issues.Add($"case.tags:{item.Id}");
        if (item.Snapshot is null || item.Snapshot.BeneficiaryId == Guid.Empty)
        { issues.Add($"case.snapshot:{item.Id}"); return; }
        if (!Decisions.Contains(item.ExpectedDecision)) issues.Add($"case.expected_decision:{item.Id}");
        try
        {
            var request = CreateRequest(corpus, item);
            if (request.Sources.Count == 0 || request.Sources.Count > 8 || request.Sources.Values.Any(value =>
                    string.IsNullOrWhiteSpace(value) || value.Length > 4000)) issues.Add($"case.sources:{item.Id}");
            if (item.Expected is null || !HealthParseResultValidator.TryValidate(request, item.Expected, out var facts))
            { issues.Add($"case.expected_output:{item.Id}"); return; }
            var decision = EvaluateDecision(item, concepts, rules, facts, item.Expected);
            if (decision != item.ExpectedDecision) issues.Add($"case.expected_decision_mismatch:{item.Id}");
        }
        catch (Exception error) when (error is ArgumentException or InvalidOperationException or NullReferenceException or System.Text.Json.JsonException)
        { issues.Add($"case.invalid:{item.Id}"); }
    }

    private static string EvaluateDecision(HealthParserEvaluationCase item, IReadOnlyList<NutritionConcept> concepts,
        IReadOnlyList<DietaryRule> rules, HealthFact[] parsedFacts, HealthParseResult output)
    {
        var health = HealthSnapshotNormalizer.Normalize(item.Snapshot, concepts);
        health = health with
        {
            Unresolved = health.Unresolved.Concat(HealthParseResultValidator.UnresolvedFields(output))
                .Distinct(StringComparer.Ordinal).ToArray()
        };
        return NutritionEligibilityPolicy.Evaluate(item.Snapshot, health,
            health.Facts.Concat(parsedFacts).ToArray(), rules, false).State;
    }

    private static string FactIdentity(HealthParseFact fact) =>
        $"{fact.Kind}\u001f{fact.Code}\u001f{fact.Assertion}\u001f{fact.Temporality}\u001f{fact.Subject}\u001f{fact.SourceKey}\u001f{fact.Quote}\u001f{fact.StartOffset}\u001f{fact.EndOffset}";

    private static string UnresolvedIdentity(HealthUnresolvedStatement item) =>
        $"{item.SourceKey}\u001f{item.Quote}\u001f{item.StartOffset}\u001f{item.EndOffset}\u001f{item.Reason}";

    private static int GetCount(IReadOnlyDictionary<string, int> values, string key) =>
        values.TryGetValue(key, out var value) ? value : 0;

    private static void CountKinds(IEnumerable<HealthParseFact> facts, IDictionary<string, int> counts)
    {
        foreach (var fact in facts) Increment(counts, fact.Kind);
    }

    private static void Increment(IDictionary<string, int> counts, string key) =>
        counts[key] = counts.TryGetValue(key, out var value) ? value + 1 : 1;

    private static double Ratio(int numerator, int denominator) => denominator == 0 ? 1 :
        Math.Round((double)numerator / denominator, 6, MidpointRounding.AwayFromZero);

    private static long Percentile(long[] sorted, double percentile) => sorted.Length == 0 ? 0 :
        sorted[Math.Clamp((int)Math.Ceiling(sorted.Length * percentile) - 1, 0, sorted.Length - 1)];
}
