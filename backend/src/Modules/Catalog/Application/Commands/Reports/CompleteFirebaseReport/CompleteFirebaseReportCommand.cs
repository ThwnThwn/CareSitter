using CareSitter.Modules.Catalog.Application;
using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Catalog.Application.Commands.Reports;

internal sealed record CompleteFirebaseReportCommand(Guid ReportId)
    : IRequest<Result<ReportResponse>>;

internal sealed class CompleteFirebaseReportCommandHandler(FirebaseReportService firebase)
    : IRequestHandler<CompleteFirebaseReportCommand, Result<ReportResponse>>
{
    public Task<Result<ReportResponse>> Handle(
        CompleteFirebaseReportCommand request, CancellationToken ct) =>
        firebase.CompleteAsync(request.ReportId, ct);
}
