using CareSitter.Nutrition.Application;
using CareSitter.Nutrition.Contracts;
using CareSitter.Nutrition.Domain;
using CareSitter.Nutrition.Infrastructure;
using Npgsql;

namespace CareSitter.Nutrition.Tests;

public sealed partial class PostgresWorkflowTests
{
    [PostgresFact]
    public async Task Waiting_recommendation_lock_observes_cancellation_without_running_action()
    {
        var key = Guid.NewGuid();
        var entered = new TaskCompletionSource(TaskCreationOptions.RunContinuationsAsynchronously);
        var resume = new TaskCompletionSource(TaskCreationOptions.RunContinuationsAsynchronously);
        using var deadline = new CancellationTokenSource(TimeSpan.FromSeconds(10));
        var first = _store.InRecommendationScopeAsync(_owner, key, async () =>
        { entered.SetResult(); await resume.Task.WaitAsync(deadline.Token); return true; }, deadline.Token);
        try
        {
            await entered.Task.WaitAsync(deadline.Token);
            using var cancel = new CancellationTokenSource(TimeSpan.FromMilliseconds(200));
            await Assert.ThrowsAnyAsync<OperationCanceledException>(() => _store.InRecommendationScopeAsync<bool>(
                _owner, key, () => throw new Xunit.Sdk.XunitException("Cancelled waiter entered action."), cancel.Token));
        }
        finally { resume.TrySetResult(); }
        Assert.True(await first);
    }

    [PostgresFact]
    public async Task Lock_pool_resets_session_locks_and_failed_unlock_does_not_block_retry()
    {
        await using (var held = await _lockDataSource.OpenConnectionAsync(default))
        {
            await using var acquire = new NpgsqlCommand("SELECT pg_advisory_lock(987654321::bigint)", held);
            await acquire.ExecuteNonQueryAsync();
            // Dispose without explicit unlock: test reset-on-close on the actual lock pool.
        }
        await using (var reused = await _lockDataSource.OpenConnectionAsync(default))
        {
            await using var flush = new NpgsqlCommand("SELECT 1", reused);
            await flush.ExecuteScalarAsync(); // Npgsql flushes its deferred reset before this command.
        }
        await using (var probe = new NpgsqlConnection(_database))
        {
            await probe.OpenAsync();
            await using var acquire = new NpgsqlCommand("SELECT pg_try_advisory_lock(987654321::bigint)", probe);
            Assert.Equal(true, await acquire.ExecuteScalarAsync());
            await using var release = new NpgsqlCommand("SELECT pg_advisory_unlock(987654321::bigint)", probe);
            await release.ExecuteNonQueryAsync();
        }
        var key = Guid.NewGuid();
        await Assert.ThrowsAnyAsync<NpgsqlException>(() => _store.InRecommendationScopeAsync(_owner, key, async () =>
        {
            // Sever the session while action is running so the finally-unlock fails.
            await SqlAsync("SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname=current_database() AND application_name LIKE '%/recommendation-lock'");
            return true;
        }, default));
        using var deadline = new CancellationTokenSource(TimeSpan.FromSeconds(10));
        Assert.True(await _store.InRecommendationScopeAsync(_owner, key, () => Task.FromResult(true), deadline.Token));
    }

    private async Task<Guid> ConcurrentMealFixtureAsync()
    {
        foreach (var meal in new[] { "breakfast", "lunch", "dinner", "lunch" })
        {
            var recipe = EligibilityTests.Recipe(meal, 1);
            await using var db = new NpgsqlConnection(_database);
            await db.OpenAsync();
            await using var command = new NpgsqlCommand("""
                INSERT INTO nutrition.recipe_versions(id,recipe_id,version,status,payload,reviewed_by,reviewed_at,published_at)
                VALUES(@id,@id,1,'published',@payload::jsonb,'fixture reviewer',now(),now())
                """, db);
            command.Parameters.AddWithValue("id", recipe.VersionId);
            command.Parameters.AddWithValue("payload", NutritionJson.Write(recipe));
            await command.ExecuteNonQueryAsync();
        }
        await RegisterRawCatalogFixtureAsync();
        var assessment = await AssessAsync();
        await ProcessAsync();
        Assert.Equal("confirmed", (await Handler().Handle(Request("confirm", assessment), default)).Value.Status);
        return assessment;
    }

    private async Task<int> RowCountAsync(string table)
    {
        // Table names come only from literals in this test class; use admin to bypass RLS for counts.
        await using var db = new NpgsqlConnection(_database);
        await db.OpenAsync();
        await using var command = new NpgsqlCommand($"SELECT count(*)::int FROM nutrition.{table}", db);
        return (int)(await command.ExecuteScalarAsync())!;
    }

    [PostgresFact]
    public async Task Concurrent_assessment_retry_creates_one_job_and_consumes_one_quota_slot()
    {
        var request = Request();
        var results = await Task.WhenAll(Enumerable.Range(0, 12).Select(_ => Handler().Handle(request, default)));
        Assert.All(results, result => Assert.True(result.IsSuccess));
        Assert.Single(results.Select(result => result.Value.Id).Distinct());
        Assert.Equal(1, await RowCountAsync("assessments"));
        Assert.Equal(1, await RowCountAsync("assessment_jobs"));
        for (var i = 0; i < 19; i++) Assert.True((await Handler().Handle(Request(), default)).IsSuccess);
        Assert.Equal("nutrition.quota", (await Handler().Handle(Request(), default)).Error.Code);
    }

    [PostgresFact]
    public async Task Concurrent_meal_retries_replay_one_resource_for_each_operation()
    {
        var assessment = await ConcurrentMealFixtureAsync();
        var recommend = Request("recommend", assessment: assessment);
        var recommendations = await Task.WhenAll(Enumerable.Range(0, 8).Select(_ => Handler().Handle(recommend, default)));
        Assert.All(recommendations, result => Assert.True(result.IsSuccess));
        var original = Assert.Single(recommendations.Select(result => result.Value.Id).Distinct());
        Assert.Equal(1, await RowCountAsync("recommendations"));
        var options = await new ReplacementOptionsQueryHandler(_people, _store, new Actor(_owner, "CUSTOMER"), new Features())
            .Handle(new(recommend.BeneficiaryId, original, "lunch"), default);
        var replace = Request("replace", original);
        replace = replace with { Input = replace.Input with { MealType = "lunch", RecipeVersionId = options.Value[0].VersionId } };
        var replacements = await Task.WhenAll(Enumerable.Range(0, 8).Select(_ => Handler().Handle(replace, default)));
        Assert.All(replacements, result => Assert.True(result.IsSuccess));
        var replaced = Assert.Single(replacements.Select(result => result.Value.Id).Distinct());
        Assert.Equal(2, await RowCountAsync("recommendations"));
        var save = Request("save", replaced);
        save = save with { Input = save.Input with { PlannedDate = DateOnly.Parse(replacements[0].Value.Data.GetProperty("plannedDate").GetString()!) } };
        var plans = await Task.WhenAll(Enumerable.Range(0, 8).Select(_ => Handler().Handle(save, default)));
        Assert.All(plans, result => Assert.True(result.IsSuccess));
        Assert.Single(plans.Select(result => result.Value.Id).Distinct());
        Assert.Equal(1, await RowCountAsync("meal_plans"));
    }

    [PostgresFact]
    public async Task Concurrent_recommendation_ranking_replays_loser_without_unique_violation()
    {
        var assessment = await ConcurrentMealFixtureAsync();
        var request = (RecommendMealsCommand)Request("recommend", assessment: assessment);
        using var deadline = new CancellationTokenSource(TimeSpan.FromSeconds(15));
        var engine = new TwoRequestRanker();
        var handler = new RecommendMealsCommandHandler(new NutritionWriteScope(_people, _store,
            new Actor(_owner, "CUSTOMER"), new Features()), new(),
            new MealRecommendationEngine(new ConcurrencyKnowledge(), engine));
        var first = handler.Handle(request, deadline.Token);
        await engine.FirstEntered.Task.WaitAsync(deadline.Token);
        var second = handler.Handle(request, deadline.Token);
        // Before deduplication both enter ranking; afterwards the loser waits in PostgreSQL.
        while (!engine.BothEntered.Task.IsCompleted && !await HasRequestLockWaiterAsync())
            await Task.Delay(20, deadline.Token);
        engine.Resume.TrySetResult();
        var results = await Task.WhenAll(first, second);
        Assert.All(results, result => Assert.True(result.IsSuccess));
        Assert.Single(results.Select(result => result.Value.Id).Distinct());
        Assert.Equal(1, await RowCountAsync("recommendations"));
        Assert.Equal(1, engine.Calls);
        await handler.Handle(request, deadline.Token);
        Assert.Equal(1, engine.Calls);
    }

    private async Task<bool> HasRequestLockWaiterAsync()
    {
        await using var db = new NpgsqlConnection(_database);
        await db.OpenAsync();
        await using var command = new NpgsqlCommand("""
            SELECT count(*) >= 2 FROM pg_stat_activity WHERE datname=current_database()
              AND pid<>pg_backend_pid() AND query LIKE '%pg_try_advisory_lock%nutrition-request:%'
            """, db);
        return (bool)(await command.ExecuteScalarAsync())!;
    }

    [PostgresFact]
    public async Task Recommendation_lock_does_not_exhaust_single_connection_transaction_pool()
    {
        var assessment = await ConcurrentMealFixtureAsync();
        await using var single = NpgsqlDataSource.Create(new NpgsqlConnectionStringBuilder(_database)
        { Username = _role, Password = _rolePassword, MaxPoolSize = 1, Timeout = 2 }.ConnectionString);
        var handler = new CommandDispatcher(new NutritionWriteScope(_people, new NutritionStore(single, _lockDataSource),
            new Actor(_owner, "CUSTOMER"), new Features()));
        using var deadline = new CancellationTokenSource(TimeSpan.FromSeconds(8));
        var result = await handler.Handle(Request("recommend", assessment: assessment), deadline.Token);
        Assert.True(result.IsSuccess);
        Assert.Equal("suggested", result.Value.Status);
    }

    [PostgresFact]
    public async Task Different_recommendation_keys_can_rank_concurrently()
    {
        var assessment = await ConcurrentMealFixtureAsync();
        using var deadline = new CancellationTokenSource(TimeSpan.FromSeconds(15));
        var ranker = new TwoRequestRanker();
        var handler = new RecommendMealsCommandHandler(new NutritionWriteScope(_people, _store,
            new Actor(_owner, "CUSTOMER"), new Features()), new(),
            new MealRecommendationEngine(new ConcurrencyKnowledge(), ranker));
        var first = handler.Handle((RecommendMealsCommand)Request("recommend", assessment: assessment), deadline.Token);
        var second = handler.Handle((RecommendMealsCommand)Request("recommend", assessment: assessment), deadline.Token);
        try { await ranker.BothEntered.Task.WaitAsync(deadline.Token); }
        finally { ranker.Resume.TrySetResult(); }
        var results = await Task.WhenAll(first, second);
        Assert.All(results, result => Assert.True(result.IsSuccess));
        Assert.Equal(2, results.Select(result => result.Value.Id).Distinct().Count());
        Assert.Equal(2, ranker.Calls);
        Assert.Equal(2, await RowCountAsync("recommendations"));
    }

    [PostgresFact]
    public async Task Cancelled_ranking_releases_database_lock_and_same_key_can_retry()
    {
        var assessment = await ConcurrentMealFixtureAsync();
        var request = (RecommendMealsCommand)Request("recommend", assessment: assessment);
        var ranker = new TwoRequestRanker();
        var handler = new RecommendMealsCommandHandler(new NutritionWriteScope(_people, _store,
            new Actor(_owner, "CUSTOMER"), new Features()), new(),
            new MealRecommendationEngine(new ConcurrencyKnowledge(), ranker));
        using var cancelled = new CancellationTokenSource(TimeSpan.FromSeconds(15));
        var first = handler.Handle(request, cancelled.Token);
        await ranker.FirstEntered.Task.WaitAsync(cancelled.Token);
        cancelled.Cancel();
        await Assert.ThrowsAnyAsync<OperationCanceledException>(() => first);
        Assert.Equal(0, await RowCountAsync("recommendations"));
        ranker.Resume.TrySetResult();
        using var deadline = new CancellationTokenSource(TimeSpan.FromSeconds(15));
        var retry = await handler.Handle(request, deadline.Token);
        Assert.True(retry.IsSuccess);
        Assert.Equal(1, await RowCountAsync("recommendations"));
        var replay = await handler.Handle(request, deadline.Token);
        Assert.Equal(retry.Value.Id, replay.Value.Id);
        Assert.Equal(2, ranker.Calls);
    }

    private sealed class ConcurrencyKnowledge : IMealKnowledgeRetriever
    {
        public Task<MealKnowledgeResult> RetrieveAsync(MealKnowledgeRequest request, CancellationToken ct) =>
            Task.FromResult(new MealKnowledgeResult(true, "fixture-revision", "graph",
                [new("evidence-1", "Fixture", null, "1", "pdf-page:1", "Fixture page 1", "Synthetic fixture")], []));
    }

    private sealed class TwoRequestRanker : IMealCandidateRanker
    {
        public int Calls;
        public TaskCompletionSource FirstEntered { get; } = new(TaskCreationOptions.RunContinuationsAsynchronously);
        public TaskCompletionSource BothEntered { get; } = new(TaskCreationOptions.RunContinuationsAsynchronously);
        public TaskCompletionSource Resume { get; } = new(TaskCreationOptions.RunContinuationsAsynchronously);
        public async Task<MealCandidateRankingResult> RankAsync(MealCandidateRankingRequest request, CancellationToken ct)
        {
            if (Interlocked.Increment(ref Calls) == 2) BothEntered.TrySetResult();
            FirstEntered.TrySetResult();
            await Resume.Task.WaitAsync(ct);
            return new(true, request.CandidateSets[0].Select(recipe => recipe.VersionId).ToArray(),
                "fixture-model", "fixture-prompt", [], []);
        }
    }

    [PostgresFact]
    public async Task Lost_response_after_commit_retries_same_resource_for_all_creation_operations()
    {
        var assessment = await ConcurrentMealFixtureAsync();
        Guid recommendation = Guid.Empty;
        foreach (var operation in new[] { "assess", "recommend", "replace", "save" })
        {
            var request = Request(operation, recommendation, assessment);
            if (operation == "replace")
            {
                var options = await new ReplacementOptionsQueryHandler(_people, _store, new Actor(_owner, "CUSTOMER"), new Features())
                    .Handle(new(request.BeneficiaryId, recommendation, "lunch"), default);
                request = request with { Input = request.Input with { MealType = "lunch", RecipeVersionId = options.Value[0].VersionId } };
            }
            var kind = operation == "assess" ? "assessment" : operation == "save" ? "plan" : "recommendation";
            var table = kind == "assessment" ? "assessments" : kind == "plan" ? "meal_plans" : "recommendations";
            var before = await RowCountAsync(table);
            var afterCommit = _people.Reads + (operation == "recommend" ? 4 : 2);
            _people.OnRead = read => { if (read == afterCommit) throw new IOException("Injected response loss after commit."); };
            await Assert.ThrowsAsync<IOException>(() => Handler().Handle(request, default));
            _people.OnRead = null;
            var stored = await _store.InOwnerScopeAsync(_owner,
                session => session.FindByKeyAsync(kind, request.IdempotencyKey, default), default);
            Assert.NotNull(stored);
            var replay = await Handler().Handle(request, default);
            Assert.True(replay.IsSuccess);
            Assert.Equal(stored.Id, replay.Value.Id);
            Assert.Equal(stored.CreatedAt, replay.Value.CreatedAt);
            Assert.Equal(stored.HealthRevision, replay.Value.HealthRevision);
            Assert.Equal(stored.Status, replay.Value.Status);
            Assert.Equal(NutritionJson.Read<System.Text.Json.JsonElement>(stored.Payload).ToString(), replay.Value.Data.ToString());
            Assert.Equal(before + 1, await RowCountAsync(table));
            if (operation is "recommend" or "replace") recommendation = replay.Value.Id;
        }
    }

    [PostgresFact]
    public async Task Resumed_old_worker_cannot_overwrite_new_completed_assessment()
    {
        _people.Source = _people.Source with { GeneralNote = "Synthetic note for worker fencing." };
        var id = await AssessAsync();
        var first = (await _store.ClaimAsync(default))!.Value;
        using var deadline = new CancellationTokenSource(TimeSpan.FromSeconds(15));
        var oldParser = new PausedWorkerParser();
        var oldWorker = new AssessmentProcessor(_people, _store, oldParser).ProcessAsync(first, deadline.Token);
        await oldParser.Entered.Task.WaitAsync(deadline.Token);
        try
        {
            await SqlAsync("UPDATE nutrition.assessment_jobs SET lease_until=now()-interval '1 second'");
            var second = (await _store.ClaimAsync(default))!.Value;
            Assert.NotEqual(first.Token, second.Token);
            Assert.Equal(2, second.Attempts);
            await new AssessmentProcessor(_people, _store, new CompletedWorkerParser()).ProcessAsync(second, deadline.Token);
            var completed = await ReadAsync("assessment", id);
            Assert.Equal("new-worker.v1", completed.Value.Data.GetProperty("parserPromptVersion").GetString());
            Assert.Equal(0, await RowCountAsync("assessment_jobs"));
            oldParser.Resume.TrySetResult();
            await oldWorker;
            var after = await ReadAsync("assessment", id);
            Assert.Equal(completed.Value.Status, after.Value.Status);
            Assert.Equal(completed.Value.Data.ToString(), after.Value.Data.ToString());
            Assert.Null(await _store.ClaimAsync(deadline.Token));
        }
        finally { oldParser.Resume.TrySetResult(); await oldWorker; }
    }

    private sealed class CompletedWorkerParser : IHealthDescriptionParser
    {
        public bool IsReady => true;
        public string PromptVersion => "new-worker.v1";
        public Task<HealthParseResult> ParseAsync(HealthParseRequest request, CancellationToken ct) =>
            Task.FromResult(new HealthParseResult(request.SchemaVersion, request.DictionaryRevision, [], [], ["generalNote"]));
    }

    private sealed class PausedWorkerParser : IHealthDescriptionParser
    {
        public bool IsReady => true;
        public string PromptVersion => "old-worker.v1";
        public TaskCompletionSource Entered { get; } = new(TaskCreationOptions.RunContinuationsAsynchronously);
        public TaskCompletionSource Resume { get; } = new(TaskCreationOptions.RunContinuationsAsynchronously);
        public async Task<HealthParseResult> ParseAsync(HealthParseRequest request, CancellationToken ct)
        {
            Entered.TrySetResult();
            await Resume.Task.WaitAsync(ct);
            throw new HealthParserException("nutrition.ai_timeout", true);
        }
    }

    [PostgresFact]
    public async Task Interrupted_week_preserves_committed_days_and_exposes_unsaved_days_on_retry()
    {
        var assessment = await ConcurrentMealFixtureAsync();
        var start = new DateOnly(2027, 1, 4);
        var saves = new List<NutritionWriteCommand>();
        for (var day = 0; day < 7; day++)
        {
            var recommend = Request("recommend", assessment: assessment);
            recommend = recommend with { Input = recommend.Input with { PlannedDate = start.AddDays(day) } };
            var result = await Handler().Handle(recommend, default);
            Assert.Equal("suggested", result.Value.Status);
            var save = Request("save", result.Value.Id);
            saves.Add(save with { Input = save.Input with { PlannedDate = start.AddDays(day) } });
        }
        var first = await Handler().Handle(saves[0], default);
        var afterCommit = _people.Reads + 2;
        _people.OnRead = read => { if (read == afterCommit) throw new IOException("Injected interruption of weekly saves."); };
        await Assert.ThrowsAsync<IOException>(() => Handler().Handle(saves[1], default));
        _people.OnRead = null;
        var queries = new NutritionResourceQueryHandler(_people, _store, new Actor(_owner, "CUSTOMER"), new Features());
        var partial = await queries.Handle(new ListMealPlansQuery(_people.Source.BeneficiaryId, start), default);
        Assert.Equal(2, partial.Value.Count);
        Assert.All(partial.Value, plan => Assert.Equal("saved", plan.Status));
        Assert.DoesNotContain(partial.Value, plan => plan.Data.GetProperty("plannedDate").GetString() == "2027-01-06");
        var secondReplay = await Handler().Handle(saves[1], default);
        Assert.Contains(partial.Value, plan => plan.Id == secondReplay.Value.Id);
        for (var day = 0; day < 2; day++)
        {
            var newAttempt = saves[day] with { Input = saves[day].Input with { IdempotencyKey = Guid.NewGuid() } };
            Assert.Equal("nutrition.plan_date_occupied", (await Handler().Handle(newAttempt, default)).Error.Code);
        }
        for (var day = 2; day < 7; day++)
            Assert.Equal("saved", (await Handler().Handle(saves[day], default)).Value.Status);
        var complete = await queries.Handle(new ListMealPlansQuery(_people.Source.BeneficiaryId, start), default);
        Assert.Equal(7, complete.Value.Count);
        foreach (var committed in partial.Value)
        {
            var retained = Assert.Single(complete.Value, plan => plan.Id == committed.Id);
            Assert.Equal(committed.Data.ToString(), retained.Data.ToString());
        }
        Assert.Contains(complete.Value, plan => plan.Id == first.Value.Id);
        Assert.Equal(7, await RowCountAsync("meal_plans"));
    }
}
