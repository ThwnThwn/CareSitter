using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Booking.Application;

internal sealed class ListCareTasksQueryHandler(ICareTaskManager manager)
    : IRequestHandler<ListCareTasksQuery, Result<IReadOnlyList<CareTaskResponse>>>
{
    public Task<Result<IReadOnlyList<CareTaskResponse>>> Handle(
        ListCareTasksQuery request, CancellationToken ct) =>
        manager.ListAsync(request.BookingId, ct);
}
