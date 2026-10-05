using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Support.Application.Commands.UpdateSupportTicketStatus;

public sealed record UpdateSupportTicketStatusCommand(Guid TicketId, string Status)
    : IRequest<Result<SupportTicketResponse>>;
