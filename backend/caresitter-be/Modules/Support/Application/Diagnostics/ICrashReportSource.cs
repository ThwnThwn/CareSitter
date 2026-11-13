using CareSitter.SharedKernel.Results;

namespace CareSitter.Modules.Support.Application.Diagnostics;

public sealed record CrashReportItem(string EventId, string IssueId, DateTimeOffset OccurredAt,
    string ErrorType, string AppVersion, string BuildVersion, string Platform,
    string Screen, string DemoRunId);
public sealed record CrashReportPage(string SourceStatus, string ExportMode, DateTimeOffset QueriedAt,
    DateTimeOffset WindowEnd, int Days, int Page, int PageSize, bool HasMore,
    IReadOnlyList<CrashReportItem> Items);
public sealed record CrashReportFilter(DateTimeOffset Until, int Days, int Page, int PageSize, string? ErrorType);

public interface ICrashReportSource
{
    Task<Result<CrashReportPage>> ReadAsync(CrashReportFilter filter, CancellationToken ct);
}
