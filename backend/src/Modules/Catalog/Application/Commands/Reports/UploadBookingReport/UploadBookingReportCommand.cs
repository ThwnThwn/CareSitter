using CareSitter.Modules.Catalog.Application;
using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Catalog.Application.Commands.Reports;

internal sealed record UploadBookingReportCommand(
    Guid BookingId,
    Guid IdempotencyKey,
    byte[] Content)
    : IRequest<Result<ReportResponse>>;

internal sealed class UploadBookingReportCommandHandler(ReportService reports)
    : IRequestHandler<UploadBookingReportCommand, Result<ReportResponse>>
{
    public Task<Result<ReportResponse>> Handle(
        UploadBookingReportCommand request, CancellationToken ct) =>
        reports.UploadAsync(request.BookingId, request.IdempotencyKey, request.Content, ct);
}
