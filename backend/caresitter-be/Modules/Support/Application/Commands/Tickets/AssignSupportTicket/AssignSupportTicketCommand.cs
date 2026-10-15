using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Support.Application.Commands.AssignSupportTicket;

public sealed record AssignSupportTicketCommand(Guid TicketId, long? ExpectedVersion = null)
    : IRequest<Result<SupportTicketResponse>>;
