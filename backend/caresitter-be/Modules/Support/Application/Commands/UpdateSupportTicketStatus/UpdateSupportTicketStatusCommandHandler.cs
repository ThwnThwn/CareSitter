using CareSitter.Contracts.Services;
using CareSitter.Modules.Support.Domain;
using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Support.Application.Commands.UpdateSupportTicketStatus;

internal sealed class UpdateSupportTicketStatusCommandHandler(
    ISupportRepository repository,
    ICurrentUser currentUser,
    IAuditLogger auditLogger)
    : IRequestHandler<UpdateSupportTicketStatusCommand, Result<SupportTicketResponse>>
{
    public async Task<Result<SupportTicketResponse>> Handle(
        UpdateSupportTicketStatusCommand request, CancellationToken ct)
    {
        if (!currentUser.IsInRole("ADMIN")) return SupportErrors.Forbidden();

        var ticket = await repository.GetSupportTicketAsync(request.TicketId, ct);
        if (ticket is null) return SupportErrors.NotFound();

        var before = new { ticket.Status };
        var result = ticket.UpdateStatus(request.Status);
        if (result.IsFailure) return result.Error;

        await repository.SaveChangesAsync(ct);
        await auditLogger.WriteAsync("ADMIN_SUPPORT_TICKET_STATUS_UPDATED", "SupportTicket", ticket.Id,
            before, new { ticket.Status, ticket.AssignedAdminId }, ct);
        return SupportResponseMapper.ToResponse(ticket);
    }
}
