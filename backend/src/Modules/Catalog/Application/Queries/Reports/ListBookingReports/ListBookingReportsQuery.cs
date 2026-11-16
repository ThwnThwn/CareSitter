using CareSitter.Modules.Catalog.Application;
using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Catalog.Application.Queries.Reports;

internal sealed record ListBookingReportsQuery(
    Guid BookingId,
    int Page,
    int PageSize)
    : IRequest<Result<IReadOnlyList<ReportResponse>>>;

internal sealed class ListBookingReportsQueryHandler(ReportService reports)
    : IRequestHandler<ListBookingReportsQuery, Result<IReadOnlyList<ReportResponse>>>
{
    public Task<Result<IReadOnlyList<ReportResponse>>> Handle(
        ListBookingReportsQuery request, CancellationToken ct) =>
        reports.ListAsync(request.BookingId, request.Page, request.PageSize, ct);
}
