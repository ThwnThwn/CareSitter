using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Booking.Application;

internal sealed class SkipCareTaskCommandHandler(ICareTaskManager manager)
    : IRequestHandler<SkipCareTaskCommand, Result<CareTaskResponse>>
{
    public Task<Result<CareTaskResponse>> Handle(SkipCareTaskCommand request, CancellationToken ct) =>
        manager.SkipAsync(request.BookingId, request.TaskId, request.SkipReason, ct);
}
