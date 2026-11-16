using CareSitter.Modules.Catalog.Application;
using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Catalog.Application.Queries.Reports;

internal sealed record ReadBookingReportContentQuery(Guid ReportId)
    : IRequest<Result<byte[]>>;

internal sealed class ReadBookingReportContentQueryHandler(ReportService reports)
    : IRequestHandler<ReadBookingReportContentQuery, Result<byte[]>>
{
    public Task<Result<byte[]>> Handle(
        ReadBookingReportContentQuery request, CancellationToken ct) =>
        reports.ReadAsync(request.ReportId, ct);
}
