using CareSitter.Modules.Catalog.Application;
using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Catalog.Application.Commands.Reports;

internal sealed record PrepareFirebaseReportCommand(
    Guid BookingId,
    PrepareFirebaseReport Report,
    long AccessExpiresAtMs)
    : IRequest<Result<FirebaseReportSession>>;

internal sealed class PrepareFirebaseReportCommandHandler(FirebaseReportService firebase)
    : IRequestHandler<PrepareFirebaseReportCommand, Result<FirebaseReportSession>>
{
    public Task<Result<FirebaseReportSession>> Handle(
        PrepareFirebaseReportCommand request, CancellationToken ct) =>
        firebase.PrepareAsync(request.BookingId, request.Report, request.AccessExpiresAtMs, ct);
}
