using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Booking.Application;

internal sealed class CompleteCareTaskCommandHandler(ICareTaskManager manager)
    : IRequestHandler<CompleteCareTaskCommand, Result<CareTaskResponse>>
{
    public Task<Result<CareTaskResponse>> Handle(CompleteCareTaskCommand request, CancellationToken ct) =>
        manager.CompleteAsync(request.BookingId, request.TaskId, ct);
}
