using System.Text.Json;

namespace CareSitter.IntegrationTests;

public sealed class BaselineGateContractTests
{
    [Fact]
    public void Ci_runs_database_regressions_twice_and_admin_tests_and_preserves_evidence()
    {
        var workflow = Read(".github/workflows/ci.yml");
        Assert.Contains("permissions:\n  contents: read", workflow);
        Assert.Equal(2, workflow.Split("branches: [main, develop]").Length - 1);
        Assert.Contains("-Repeat 2 -SkipFrontend", workflow);
        Assert.Contains("npm test", workflow);
        Assert.Contains("**/*.trx", workflow);
        Assert.Contains("summary.json", workflow);
        Assert.Contains("test-results/admin.xml", workflow);
        Assert.Contains("if: always()", workflow);
    }

    [Fact]
    public void Ci_workflow_and_sdk_pin_are_not_excluded_from_version_control()
    {
        var ignore = Read(".gitignore");
        Assert.Contains("!/.github/", ignore);
        Assert.Contains("!/.github/**", ignore);
        Assert.Contains("!/global.json", ignore);
        using var sdk = JsonDocument.Parse(Read("global.json"));
        Assert.False(sdk.RootElement.GetProperty("sdk").GetProperty("allowPrerelease").GetBoolean());
        Assert.Equal("latestPatch", sdk.RootElement.GetProperty("sdk").GetProperty("rollForward").GetString());
        var workflow = Read(".github/workflows/ci.yml");
        Assert.Contains("global-json-file: global.json", workflow);
        Assert.Contains("flutter-version:", workflow);
        Assert.Contains("node-version: '", workflow);
    }

    [Fact]
    public void Local_baseline_uses_disposable_services_and_includes_admin_tests_and_schema_32()
    {
        var runner = Read("backend/scripts/test-phase7.ps1");
        Assert.DoesNotContain("docker compose", runner);
        Assert.DoesNotContain("'caresitter-db'", runner);
        Assert.DoesNotContain("'caresitter-redis'", runner);
        Assert.Contains("Start-TemporaryRedis", runner);
        Assert.Contains("'127.0.0.1::6379'", runner);
        Assert.Contains("-Arguments @('test')", runner);
        Assert.Contains("SourceSha256", runner);
        Assert.Contains("$testCounters.Total -eq 0", runner);
        Assert.Contains("booking.sync_timeline_coordinates()", runner);
        Assert.Contains("booking.sync_gps_coordinates()", runner);
        Assert.Contains("promotion.promotions", runner);
        Assert.Contains("provider_create_date", runner);
        Assert.Contains("cccd_front_media_id", runner);
        Assert.Contains("delivery_type", runner);
        Assert.Contains("LegacyReplay", runner);
    }

    [Fact]
    public void Baseline_starts_the_built_api_directly_and_drains_logs_without_PowerShell_callbacks()
    {
        var runner = Read("backend/scripts/test-phase7.ps1");
        var processHelper = Read("backend/scripts/phase7-process.ps1");
        Assert.Contains("bin/Release/net8.0/CareSitter.ApiHost.dll", runner);
        Assert.DoesNotContain("Start-Process @", runner);
        Assert.Contains("Start-Phase7LoggedProcess", runner);
        Assert.Contains("Stop-Phase7LoggedProcess", runner);
        Assert.Contains("ArgumentList.Add($argument)", processHelper);
        Assert.Contains("CopyToAsync", processHelper);
        Assert.Contains("Kill($true)", processHelper);
        Assert.Contains("$logTasks.Wait(10000)", processHelper);
        Assert.Contains("test-phase7-process.ps1", Read(".github/workflows/ci.yml"));
        Assert.Contains("ci-baseline/*.log", Read(".github/workflows/ci.yml"));
        Assert.Contains("Join-Path $testResultsDirectory $testProject.BaseName", runner);
        Assert.Contains("$testCounters.Files -ne $testProjects.Count", runner);
        Assert.Contains("Test results directory already exists", runner);
    }

    [Fact]
    public void Actor_scoped_media_rate_limit_runs_after_authentication_before_authorization()
    {
        var program = Read("backend/caresitter-be/ApiHost/Program.cs");
        var authenticate = program.IndexOf("app.UseAuthentication();", StringComparison.Ordinal);
        var rateLimit = program.IndexOf("app.UseRateLimiter();", StringComparison.Ordinal);
        var authorize = program.IndexOf("app.UseAuthorization();", StringComparison.Ordinal);
        Assert.True(authenticate >= 0 && rateLimit > authenticate && authorize > rateLimit);
        Assert.Contains("options.AddPolicy(\"media-read\"", program);
        Assert.Contains("context.User.FindFirst(System.Security.Claims.ClaimTypes.NameIdentifier)", program);
    }

    [Fact]
    public void Vercel_automatic_git_deployments_are_disabled_for_all_branches()
    {
        using var configuration = JsonDocument.Parse(Read("vercel.json"));
        Assert.False(configuration.RootElement.GetProperty("git").GetProperty("deploymentEnabled").GetBoolean());
    }

    private static string Read(string relativePath)
    {
        for (var directory = new DirectoryInfo(AppContext.BaseDirectory);
             directory is not null;
             directory = directory.Parent)
        {
            if (File.Exists(Path.Combine(directory.FullName, "backend", "CareSitter.sln")))
                return File.ReadAllText(Path.Combine(directory.FullName, relativePath)).Replace("\r\n", "\n");
        }
        throw new DirectoryNotFoundException("Could not find the CareSitter repository.");
    }
}
