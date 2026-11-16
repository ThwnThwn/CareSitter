using CareSitter.Contracts.Services;
using CareSitter.Modules.Support.Application.Diagnostics;
using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Support.Application.Queries.Diagnostics;

internal sealed record ListCrashReportsQuery(
    DateTimeOffset? Until,
    int Days,
    int Page,
    int PageSize,
    string? ErrorType) : IRequest<Result<CrashReportPage>>;

internal sealed class ListCrashReportsQueryHandler(CrashReportService reports, IClock clock)
    : IRequestHandler<ListCrashReportsQuery, Result<CrashReportPage>>
{
    public Task<Result<CrashReportPage>> Handle(ListCrashReportsQuery request, CancellationToken ct) =>
        reports.ListAsync(new CrashReportFilter(
            request.Until ?? clock.UtcNow, request.Days, request.Page, request.PageSize,
            string.IsNullOrEmpty(request.ErrorType) ? null : request.ErrorType), ct);
}
