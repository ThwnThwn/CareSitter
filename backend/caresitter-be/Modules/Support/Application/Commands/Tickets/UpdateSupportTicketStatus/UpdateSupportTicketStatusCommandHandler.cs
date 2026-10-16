using CareSitter.Contracts.Services;
using CareSitter.Modules.Support.Domain;
using CareSitter.SharedKernel.Results;
using MediatR;
using CareSitter.Modules.Support.Application.Chat;

namespace CareSitter.Modules.Support.Application.Commands.UpdateSupportTicketStatus;

internal sealed class UpdateSupportTicketStatusCommandHandler(
    ISupportRepository repository,
    ICurrentUser currentUser,
    IAuditLogger auditLogger,
    IChatTicketGuard chatGuard,
    ISupportChatService chat)
    : IRequestHandler<UpdateSupportTicketStatusCommand, Result<SupportTicketResponse>>
{
    public async Task<Result<SupportTicketResponse>> Handle(
        UpdateSupportTicketStatusCommand request, CancellationToken ct)
    {
        if (!currentUser.IsInRole("ADMIN")) return SupportErrors.Forbidden();
        if (currentUser.UserId is not { } adminId) return SupportErrors.Unauthenticated();

        var ticket = await repository.GetSupportTicketAsync(request.TicketId, ct);
        if (ticket is null) return SupportErrors.NotFound();
        if (await chatGuard.FindConversationIdAsync(ticket.Id, ct) is { } conversationId)
        {
            if (request.ExpectedVersion is not { } version)
                return Error.Conflict("support.chat.version_required",
                    "Ticket có hội thoại cần expectedVersion hoặc dùng API conversation.");
            var changed = await chat.StatusAsync(new ChatActor(adminId, true, "ADMIN"),
                conversationId, request.Status, version, request.Reason ?? string.Empty, ct);
            return changed.IsFailure ? changed.Error : SupportResponseMapper.ToResponse(ticket);
        }

        var before = new { ticket.Status };
        var result = ticket.UpdateStatus(request.Status);
        if (result.IsFailure) return result.Error;
        ticket.AdvanceVersion();

        await repository.SaveChangesAsync(ct);
        await auditLogger.WriteAsync("ADMIN_SUPPORT_TICKET_STATUS_UPDATED", "SupportTicket", ticket.Id,
            before, new { ticket.Status, ticket.AssignedAdminId }, ct);
        return SupportResponseMapper.ToResponse(ticket);
    }
}
