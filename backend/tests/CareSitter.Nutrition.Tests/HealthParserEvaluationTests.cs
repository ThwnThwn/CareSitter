using CareSitter.Nutrition.Application;
using CareSitter.Nutrition.Application.Evaluation;
using CareSitter.Nutrition.ParserEval;

namespace CareSitter.Nutrition.Tests;

public sealed class HealthParserEvaluationTests
{
    [Fact]
    public void Synthetic_corpus_is_valid_and_has_group_isolated_splits()
    {
        var corpus = ParserEvalCorpusFactory.Create();

        var result = HealthParserEvaluation.Validate(corpus);

        Assert.True(result.IsValid, string.Join(',', result.Issues));
        Assert.Equal(200, result.CaseCount);
        Assert.Equal(0, result.ReviewedCaseCount);
        Assert.Equal(100, result.SplitCounts["development"]);
        Assert.Equal(50, result.SplitCounts["validation"]);
        Assert.Equal(50, result.SplitCounts["holdout"]);
        Assert.All(corpus.Cases.GroupBy(item => item.RootScenarioId), group =>
            Assert.Single(group.Select(item => item.Split).Distinct(StringComparer.Ordinal)));
    }

    [Fact]
    public void Perfect_holdout_run_passes_technical_gate_but_not_unreviewed_release_gate()
    {
        var corpus = ParserEvalCorpusFactory.Create();
        var run = PerfectRun(corpus, "holdout");

        var report = HealthParserEvaluation.Score(corpus, run);

        Assert.True(report.TechnicalGatePassed, string.Join(',', report.Issues));
        Assert.False(report.ReleaseGatePassed);
        Assert.Equal(50, report.ExactCases);
        Assert.Equal(1, report.FactPrecision);
        Assert.Equal(1, report.FactRecall);
        Assert.Equal(1, report.ProvenanceValidityRate);
        Assert.Equal(1, report.DecisionAccuracy);
        Assert.All(report.FactKindMetrics.Values, metric =>
        {
            Assert.Equal(1, metric.Precision);
            Assert.Equal(1, metric.Recall);
        });
        Assert.All(report.TagExactMatchRates.Values, rate => Assert.Equal(1, rate));
    }

    [Fact]
    public void Missing_release_blocking_output_fails_both_gates()
    {
        var corpus = ParserEvalCorpusFactory.Create();
        var run = PerfectRun(corpus, "holdout");
        run.Cases[0] = run.Cases[0] with { Output = null, ErrorCode = "nutrition.ai_invalid_output" };

        var report = HealthParserEvaluation.Score(corpus, run);

        Assert.False(report.TechnicalGatePassed);
        Assert.False(report.ReleaseGatePassed);
        Assert.Contains(run.Cases[0].CaseId, report.CriticalFailureIds);
    }

    [Fact]
    public void Malformed_null_case_is_reported_instead_of_throwing()
    {
        var source = ParserEvalCorpusFactory.Create();
        var corpus = source with { Cases = [null!] };

        var result = HealthParserEvaluation.Validate(corpus);

        Assert.False(result.IsValid);
        Assert.Contains("corpus.case_ids", result.Issues);
    }

    private static HealthParserEvaluationRun PerfectRun(HealthParserEvaluationCorpus corpus, string split)
    {
        var started = new DateTimeOffset(2026, 10, 16, 0, 0, 0, TimeSpan.Zero);
        var cases = corpus.Cases.Where(item => item.Split == split).OrderBy(item => item.Id, StringComparer.Ordinal)
            .Select(item => new HealthParserEvaluationRunCase(item.Id, item.Expected, null, 100, 100, 50)).ToArray();
        return new(HealthParserEvaluation.SchemaVersion, corpus.CorpusVersion, split, "fixture", "fixture",
            "fixture-v1", corpus.DictionaryRevision, HealthKnowledgeGraphRetriever.SchemaVersion,
            HealthKnowledgeGraphRetriever.Strategy, started, started.AddMinutes(1), cases);
    }
}
