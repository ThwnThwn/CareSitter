using CareSitter.Contracts.Services;
using CareSitter.Modules.Support.Domain;
using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Support.Application.Commands.AssignSupportTicket;

internal sealed class AssignSupportTicketCommandHandler(
    ISupportRepository repository,
    ICurrentUser currentUser,
    IAuditLogger auditLogger)
    : IRequestHandler<AssignSupportTicketCommand, Result<SupportTicketResponse>>
{
    public async Task<Result<SupportTicketResponse>> Handle(
        AssignSupportTicketCommand request, CancellationToken ct)
    {
        if (!currentUser.IsInRole("ADMIN")) return SupportErrors.Forbidden();
        if (currentUser.UserId is not { } adminId) return SupportErrors.Unauthenticated();

        var ticket = await repository.GetSupportTicketAsync(request.TicketId, ct);
        if (ticket is null) return SupportErrors.NotFound();

        var before = new { ticket.Status, ticket.AssignedAdminId };
        var result = ticket.AssignAdmin(adminId);
        if (result.IsFailure) return result.Error;

        await repository.SaveChangesAsync(ct);
        await auditLogger.WriteAsync("ADMIN_SUPPORT_TICKET_ASSIGNED", "SupportTicket", ticket.Id,
            before, new { ticket.Status, ticket.AssignedAdminId }, ct);
        return SupportResponseMapper.ToResponse(ticket);
    }
}
