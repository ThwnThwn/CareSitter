using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Support.Application.Commands.UpdateSupportTicketStatus;

public sealed record UpdateSupportTicketStatusCommand(Guid TicketId, string Status,
    long? ExpectedVersion = null, string? Reason = null)
    : IRequest<Result<SupportTicketResponse>>;
