using System.Globalization;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text.Json;
using CareSitter.Contracts.Services;
using CareSitter.Modules.Support.Application.Diagnostics;
using CareSitter.SharedKernel.Results;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;

namespace CareSitter.Modules.Support.Infrastructure.Diagnostics;

public sealed class BigQueryCrashReportSource(HttpClient http, IOptions<CrashReportOptions> options,
    ICrashQueryTokenProvider tokens, IClock clock, ILogger<BigQueryCrashReportSource> logger) : ICrashReportSource
{
    public static object Query(CrashReportOptions options, CrashReportFilter filter)
    {
        if (!options.Enabled || !options.IsValid) throw new ArgumentException("Invalid Crashlytics table configuration.");
        // Table is chosen exclusively from server configuration and strictly allowlisted.
        var table = $"`{options.ProjectId}.{options.Dataset}.{options.Table}`";
        var sql = $$"""
            SELECT TO_JSON_STRING(STRUCT(
              event_id AS eventId, issue_id AS issueId,
              FORMAT_TIMESTAMP('%Y-%m-%dT%H:%M:%E6SZ', event_timestamp, 'UTC') AS occurredAt,
              error_type AS errorType, application.display_version AS appVersion,
              application.build_version AS buildVersion, platform AS platform,
              (SELECT value FROM UNNEST(custom_keys) WHERE key='screen' LIMIT 1) AS screen,
              (SELECT value FROM UNNEST(custom_keys) WHERE key='demo_run_id' LIMIT 1) AS demoRunId
            )) AS report
            FROM {{table}}
            WHERE event_timestamp >= @since AND event_timestamp < @until
              AND (@error_type = '' OR error_type = @error_type)
            QUALIFY ROW_NUMBER() OVER (PARTITION BY event_id ORDER BY event_timestamp DESC)=1
            ORDER BY event_timestamp DESC, event_id DESC
            LIMIT @limit OFFSET @offset
            """;
        object Parameter(string name, string type, string value) => new { name,
            parameterType = new { type }, parameterValue = new { value } };
        return new { query = sql, useLegacySql = false, useQueryCache = true,
            location = options.Location, timeoutMs = 10000, maxResults = filter.PageSize + 1,
            maximumBytesBilled = options.MaximumBytesBilled.ToString(CultureInfo.InvariantCulture),
            parameterMode = "NAMED", queryParameters = new[] {
                Parameter("since", "TIMESTAMP", filter.Until.AddDays(-filter.Days).ToString("O")),
                Parameter("until", "TIMESTAMP", filter.Until.ToString("O")),
                Parameter("error_type", "STRING", filter.ErrorType ?? ""),
                Parameter("limit", "INT64", (filter.PageSize + 1).ToString(CultureInfo.InvariantCulture)),
                Parameter("offset", "INT64", ((filter.Page - 1)*filter.PageSize).ToString(CultureInfo.InvariantCulture))
            } };
    }

    public async Task<Result<CrashReportPage>> ReadAsync(CrashReportFilter filter, CancellationToken ct)
    {
        var settings = options.Value;
        var mode = settings.Table.EndsWith("_REALTIME", StringComparison.Ordinal) ? "streaming" : "batch";
        if (!settings.Enabled)
            return new CrashReportPage("not_configured", mode, clock.UtcNow, filter.Until,
                filter.Days, filter.Page, filter.PageSize, false, []);
        try
        {
            using var deadline = CancellationTokenSource.CreateLinkedTokenSource(ct);
            deadline.CancelAfter(TimeSpan.FromSeconds(20));
            using var request = new HttpRequestMessage(HttpMethod.Post,
                $"https://bigquery.googleapis.com/bigquery/v2/projects/{settings.ProjectId}/queries");
            request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", await tokens.GetAsync(deadline.Token));
            request.Content = JsonContent.Create(Query(settings, filter));
            using var response = await http.SendAsync(request, HttpCompletionOption.ResponseHeadersRead, deadline.Token);
            if (!response.IsSuccessStatusCode) return Unavailable();
            await using var stream = await response.Content.ReadAsStreamAsync(deadline.Token);
            using var buffer = new MemoryStream();
            var chunk = new byte[8192]; int count;
            while ((count = await stream.ReadAsync(chunk, deadline.Token)) > 0)
            {
                if (buffer.Length + count > 512 * 1024) return Unavailable();
                buffer.Write(chunk, 0, count);
            }
            using var json = JsonDocument.Parse(buffer.ToArray());
            var root = json.RootElement;
            if (!root.TryGetProperty("jobComplete", out var complete) || complete.ValueKind != JsonValueKind.True ||
                root.TryGetProperty("errors", out _) || root.TryGetProperty("pageToken", out _)) return Unavailable();
            // Never label an unfinished query or truncated provider response as an empty success.
            var items = new List<CrashReportItem>();
            if (root.TryGetProperty("rows", out var rows))
            {
                foreach (var row in rows.EnumerateArray())
                {
                    if (items.Count >= filter.PageSize + 1) break;
                    var raw = row.GetProperty("f")[0].GetProperty("v").GetString();
                    var item = JsonSerializer.Deserialize<CrashReportItem>(raw!, new JsonSerializerOptions(JsonSerializerDefaults.Web));
                    if (item is null || string.IsNullOrWhiteSpace(item.EventId)) return Unavailable();
                    items.Add(item with { EventId = Safe(item.EventId, 128), IssueId = Safe(item.IssueId, 128),
                        AppVersion = Safe(item.AppVersion, 80), BuildVersion = Safe(item.BuildVersion, 80),
                        Platform = item.Platform is "ANDROID" or "IOS" ? item.Platform : "UNKNOWN",
                        ErrorType = item.ErrorType is "FATAL" or "NON_FATAL" or "ANR" ? item.ErrorType : "UNKNOWN",
                        Screen = item.Screen is "home" or "auth" or "settings" or "bookings" or "catalog" or "nutrition" or "lab3_diagnostics" ? item.Screen : "unknown",
                        DemoRunId = Guid.TryParse(item.DemoRunId, out var run) ? run.ToString() : "" });
                }
            }
            return new CrashReportPage("ready", mode, clock.UtcNow, filter.Until, filter.Days,
                filter.Page, filter.PageSize, items.Count > filter.PageSize, items.Take(filter.PageSize).ToArray());
        }
        catch (OperationCanceledException) when (ct.IsCancellationRequested) { throw; }
        catch (Exception error)
        {
            // Provider response / credentials / raw exception messages never reach API logs.
            logger.LogWarning("Crash export unavailable ({ErrorType}).", error.GetType().Name);
            return Unavailable();
        }
    }
    private static string Safe(string? text, int max) =>
        new((text ?? "").Where(c => char.IsLetterOrDigit(c) || c is '-' or '_' or '.').Take(max).ToArray());
    private static Error Unavailable() => Error.Unavailable("crash.source_unavailable",
        "Chưa đọc được báo cáo từ Firebase export. Kiểm tra export, IAM và thời gian cập nhật.");
}
