using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Booking.Application;

internal sealed class CreateCareTaskCommandHandler(ICareTaskManager manager)
    : IRequestHandler<CreateCareTaskCommand, Result<CareTaskResponse>>
{
    public Task<Result<CareTaskResponse>> Handle(CreateCareTaskCommand request, CancellationToken ct) =>
        manager.CreateAsync(request.BookingId, request.Name, request.Description, ct);
}
