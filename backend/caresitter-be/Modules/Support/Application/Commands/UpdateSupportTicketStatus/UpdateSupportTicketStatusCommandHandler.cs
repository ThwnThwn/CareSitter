using CareSitter.Infrastructure.Security;
using CareSitter.Modules.Support.Domain;
using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Support.Application.Commands.UpdateSupportTicketStatus;

internal sealed class UpdateSupportTicketStatusCommandHandler(
    ISupportRepository repository,
    ICurrentUser currentUser)
    : IRequestHandler<UpdateSupportTicketStatusCommand, Result<SupportTicketResponse>>
{
    public async Task<Result<SupportTicketResponse>> Handle(
        UpdateSupportTicketStatusCommand request, CancellationToken ct)
    {
        if (!currentUser.IsInRole("ADMIN")) return SupportErrors.Forbidden();

        var ticket = await repository.GetSupportTicketAsync(request.TicketId, ct);
        if (ticket is null) return SupportErrors.NotFound();

        var result = ticket.UpdateStatus(request.Status);
        if (result.IsFailure) return result.Error;

        await repository.SaveChangesAsync(ct);
        return SupportResponseMapper.ToResponse(ticket);
    }
}
