using CareSitter.Contracts.Services;
using CareSitter.Modules.Support.Application.Commands;
using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Support.Application;

internal sealed class GetSupportTicketQueryHandler(
    ISupportReadStore store,
    ICurrentUser currentUser) : IRequestHandler<GetSupportTicketQuery, Result<SupportTicketResponse>>
{
    public async Task<Result<SupportTicketResponse>> Handle(GetSupportTicketQuery request, CancellationToken ct)
    {
        if (currentUser.UserId is not { } userId) return SupportErrors.Unauthenticated();
        var ticket = await store.GetTicketAsync(request.TicketId, ct);
        if (ticket is null) return SupportErrors.NotFound();
        if (!currentUser.IsInRole("ADMIN") && ticket.UserId != userId) return SupportErrors.Forbidden();
        return ticket;
    }
}
