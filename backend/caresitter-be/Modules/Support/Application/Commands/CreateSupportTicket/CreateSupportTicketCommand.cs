using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Support.Application.Commands.CreateSupportTicket;

public sealed record CreateSupportTicketCommand(string Type, string Title,
    string Description, string? Priority, Guid? BookingId, string[]? AttachmentUrls)
    : IRequest<Result<SupportTicketResponse>>;
