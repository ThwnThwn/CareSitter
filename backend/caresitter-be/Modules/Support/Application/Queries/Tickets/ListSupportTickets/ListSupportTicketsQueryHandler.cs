using CareSitter.Contracts.Services;
using CareSitter.Modules.Support.Application.Commands;
using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Support.Application;

internal sealed class ListSupportTicketsQueryHandler(
    ISupportReadStore store,
    ICurrentUser currentUser) : IRequestHandler<ListSupportTicketsQuery, Result<SupportPage<SupportTicketResponse>>>
{
    public async Task<Result<SupportPage<SupportTicketResponse>>> Handle(
        ListSupportTicketsQuery request, CancellationToken ct)
    {
        if (currentUser.UserId is not { } userId) return SupportErrors.Unauthenticated();
        return await store.ListTicketsAsync(userId, currentUser.IsInRole("ADMIN"),
            request.Status, request.Type, request.Priority, Math.Max(request.Page, 1),
            Math.Clamp(request.PageSize, 1, 50), ct);
    }
}
