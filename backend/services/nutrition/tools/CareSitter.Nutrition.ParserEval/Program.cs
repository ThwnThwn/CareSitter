using System.Diagnostics;
using System.Text.Json;
using CareSitter.Nutrition.Application;
using CareSitter.Nutrition.Application.Evaluation;
using CareSitter.Nutrition.Infrastructure;
using CareSitter.Nutrition.ParserEval;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;

const long MaximumCorpusBytes = 5 * 1024 * 1024;
const long MaximumRunBytes = 10 * 1024 * 1024;

return await RunAsync(args);

static async Task<int> RunAsync(string[] arguments)
{
    try
    {
        if (arguments.Length == 0) return Usage();
        return arguments[0] switch
        {
            "generate" when arguments.Length is 2 or 3 && OptionalForce(arguments) =>
                await GenerateAsync(arguments[1], arguments.Length == 3),
            "validate" when arguments.Length == 2 => await ValidateAsync(arguments[1]),
            "run" when arguments.Length is 4 or 5 && OptionalForce(arguments) =>
                await RunProviderAsync(arguments[1], arguments[2], arguments[3], arguments.Length == 5),
            "score" when arguments.Length is 3 or 4 =>
                await ScoreAsync(arguments[1], arguments[2], arguments.Length == 4 ? arguments[3] : null),
            _ => Usage()
        };
    }
    catch (ParserEvalException error)
    {
        Write(new { ok = false, error = error.Message });
        return error.ExitCode;
    }
    catch (JsonException error)
    {
        Write(new { ok = false, error = "Evaluation JSON is invalid.", path = error.Path ?? "$" });
        return 2;
    }
    catch (Exception error) when (error is IOException or UnauthorizedAccessException)
    {
        Write(new { ok = false, error = "Evaluation file operation failed." });
        return 3;
    }
}

static bool OptionalForce(string[] arguments) => arguments.Length is 2 or 4 || arguments[^1] == "--force";

static async Task<int> GenerateAsync(string path, bool force)
{
    var corpus = ParserEvalCorpusFactory.Create();
    var validation = HealthParserEvaluation.Validate(corpus);
    if (!validation.IsValid)
        throw new ParserEvalException($"Generated corpus failed validation: {string.Join(",", validation.Issues)}", 4);
    await WriteFileAsync(path, NutritionJson.Write(corpus), force);
    Write(new
    {
        ok = true,
        output = Path.GetFullPath(path),
        validation.CaseCount,
        validation.ReviewedCaseCount,
        validation.SplitCounts,
        releaseReady = false,
        note = "Synthetic labels remain pending specialist review."
    });
    return 0;
}

static async Task<int> ValidateAsync(string path)
{
    var corpus = await ReadAsync<HealthParserEvaluationCorpus>(path, MaximumCorpusBytes);
    var result = HealthParserEvaluation.Validate(corpus);
    Write(new
    {
        ok = result.IsValid,
        result.CaseCount,
        result.ReviewedCaseCount,
        result.SplitCounts,
        result.Issues,
        releaseReady = false
    });
    return result.IsValid ? 0 : 2;
}

static async Task<int> RunProviderAsync(string corpusPath, string runPath, string split, bool force)
{
    if (Environment.GetEnvironmentVariable("NUTRITION_PARSER_EVAL_DATA_PROCESSING_APPROVED") != "true")
        throw new ParserEvalException("Set NUTRITION_PARSER_EVAL_DATA_PROCESSING_APPROVED=true before a provider run.", 3);
    var corpus = await ReadAsync<HealthParserEvaluationCorpus>(corpusPath, MaximumCorpusBytes);
    var validation = HealthParserEvaluation.Validate(corpus);
    if (!validation.IsValid)
        throw new ParserEvalException($"Corpus validation failed: {string.Join(",", validation.Issues)}", 2);
    var selected = corpus.Cases.Where(item => item.Split == split).OrderBy(item => item.Id, StringComparer.Ordinal).ToArray();
    if (selected.Length == 0) throw new ParserEvalException("Split must be development, validation or holdout.", 2);
    EnsureWritable(runPath, force);

    var options = new HealthParserOptions
    {
        Enabled = true,
        Provider = "OpenAI",
        Model = "gpt-6-luna",
        BaseUrl = "https://api.openai.com/v1/",
        ApiKey = Environment.GetEnvironmentVariable("NUTRITION_PARSER_EVAL_API_KEY") ?? string.Empty,
        ApiKeyFile = Environment.GetEnvironmentVariable("NUTRITION_PARSER_EVAL_API_KEY_FILE") ?? string.Empty,
        DataProcessingApproved = true,
        TimeoutSeconds = 25,
        MaxOutputTokens = 2048,
        MaxAttempts = 2,
        MaxConcurrency = 1,
        DailyBudget = Math.Max(1, selected.Length * 2),
        MaxInputCharacters = 12000,
        MaxResponseBytes = 262144
    };
    var optionResult = new HealthParserOptionsValidator().Validate(null, options);
    if (optionResult.Failed)
        throw new ParserEvalException(optionResult.FailureMessage ?? "Provider options are invalid.", 3);

    using var http = new HttpClient { BaseAddress = new Uri(options.BaseUrl), Timeout = Timeout.InfiniteTimeSpan };
    using var guard = new HealthParserRuntimeGuard(options, TimeProvider.System);
    var logger = new EvaluationLogger();
    var parser = new OpenAiHealthDescriptionParser(http, Options.Create(options), guard, logger);
    var started = DateTimeOffset.UtcNow;
    var results = new List<HealthParserEvaluationRunCase>(selected.Length);
    foreach (var item in selected)
    {
        logger.Reset();
        var stopwatch = Stopwatch.StartNew();
        try
        {
            var output = await parser.ParseAsync(HealthParserEvaluation.CreateRequest(corpus, item), CancellationToken.None);
            results.Add(new(item.Id, output, null, stopwatch.ElapsedMilliseconds,
                logger.InputTokens, logger.OutputTokens));
        }
        catch (HealthParserException error)
        {
            results.Add(new(item.Id, null, error.Code, stopwatch.ElapsedMilliseconds,
                logger.InputTokens, logger.OutputTokens));
        }
        catch (OperationCanceledException)
        {
            results.Add(new(item.Id, null, "nutrition.ai_timeout", stopwatch.ElapsedMilliseconds,
                logger.InputTokens, logger.OutputTokens));
        }
    }
    var run = new HealthParserEvaluationRun(HealthParserEvaluation.SchemaVersion, corpus.CorpusVersion, split,
        options.Provider, options.Model, parser.PromptVersion ?? "unknown", corpus.DictionaryRevision,
        HealthKnowledgeGraphRetriever.SchemaVersion, HealthKnowledgeGraphRetriever.Strategy, started,
        DateTimeOffset.UtcNow, results.ToArray());
    await WriteFileAsync(runPath, NutritionJson.Write(run), force);
    var report = HealthParserEvaluation.Score(corpus, run);
    Write(new { ok = true, output = Path.GetFullPath(runPath), report });
    return report.TechnicalGatePassed ? 0 : 5;
}

static async Task<int> ScoreAsync(string corpusPath, string runPath, string? reportPath)
{
    var corpus = await ReadAsync<HealthParserEvaluationCorpus>(corpusPath, MaximumCorpusBytes);
    var run = await ReadAsync<HealthParserEvaluationRun>(runPath, MaximumRunBytes);
    var report = HealthParserEvaluation.Score(corpus, run);
    if (reportPath is not null) await WriteFileAsync(reportPath, NutritionJson.Write(report), false);
    Write(new { ok = report.TechnicalGatePassed, report });
    return report.TechnicalGatePassed ? 0 : 5;
}

static async Task<T> ReadAsync<T>(string path, long maximumBytes)
{
    var file = new FileInfo(Path.GetFullPath(path));
    if (!file.Exists) throw new ParserEvalException("Evaluation file was not found.", 2);
    if (file.Length is 0 || file.Length > maximumBytes)
        throw new ParserEvalException("Evaluation file size is outside the supported range.", 2);
    return NutritionJson.Read<T>(await File.ReadAllTextAsync(file.FullName));
}

static async Task WriteFileAsync(string path, string contents, bool force)
{
    var fullPath = Path.GetFullPath(path);
    EnsureWritable(fullPath, force);
    Directory.CreateDirectory(Path.GetDirectoryName(fullPath)!);
    var temporary = fullPath + ".tmp-" + Guid.NewGuid().ToString("N");
    try
    {
        await File.WriteAllTextAsync(temporary, contents);
        File.Move(temporary, fullPath, force);
    }
    finally
    {
        if (File.Exists(temporary)) File.Delete(temporary);
    }
}

static void EnsureWritable(string path, bool force)
{
    if (File.Exists(Path.GetFullPath(path)) && !force)
        throw new ParserEvalException("Output already exists; pass --force to replace it.", 2);
}

static void Write<T>(T value) => Console.WriteLine(JsonSerializer.Serialize(value, NutritionJson.Options));

static int Usage()
{
    Console.Error.WriteLine("Usage: parser-eval generate <corpus.json> [--force] | validate <corpus.json> | run <corpus.json> <run.json> <development|validation|holdout> [--force] | score <corpus.json> <run.json> [report.json]");
    return 1;
}

sealed class ParserEvalException(string message, int exitCode) : Exception(message)
{
    public int ExitCode { get; } = exitCode;
}

sealed class EvaluationLogger : ILogger<OpenAiHealthDescriptionParser>
{
    public long InputTokens { get; private set; }
    public long OutputTokens { get; private set; }

    public void Reset() => (InputTokens, OutputTokens) = (0, 0);
    public IDisposable? BeginScope<TState>(TState state) where TState : notnull => null;
    public bool IsEnabled(LogLevel logLevel) => true;
    public void Log<TState>(LogLevel logLevel, EventId eventId, TState state, Exception? exception,
        Func<TState, Exception?, string> formatter)
    {
        if (state is not IEnumerable<KeyValuePair<string, object?>> properties) return;
        foreach (var property in properties)
        {
            if (property.Key == "InputTokens" && property.Value is long input) InputTokens = input;
            if (property.Key == "OutputTokens" && property.Value is long output) OutputTokens = output;
        }
    }
}
