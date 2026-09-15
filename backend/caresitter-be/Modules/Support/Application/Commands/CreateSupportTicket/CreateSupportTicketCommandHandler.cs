using System.Text.Json;
using CareSitter.Infrastructure.Security;
using CareSitter.Modules.Support.Domain;
using CareSitter.SharedKernel.Results;
using FluentValidation;
using MediatR;

namespace CareSitter.Modules.Support.Application.Commands.CreateSupportTicket;

internal sealed class CreateSupportTicketCommandHandler(
    ISupportRepository repository,
    ICurrentUser currentUser,
    IValidator<CreateSupportTicketCommand> validator)
    : IRequestHandler<CreateSupportTicketCommand, Result<SupportTicketResponse>>
{
    public async Task<Result<SupportTicketResponse>> Handle(
        CreateSupportTicketCommand request, CancellationToken ct)
    {
        if (currentUser.UserId is not { } userId) return SupportErrors.Unauthenticated();

        var attachmentUrls = (request.AttachmentUrls ?? Array.Empty<string>())
            .Where(x => !string.IsNullOrWhiteSpace(x))
            .Select(x => x.Trim())
            .Distinct(StringComparer.OrdinalIgnoreCase)
            .ToArray();
        var validation = await validator.ValidateAsync(request, ct);
        if (!validation.IsValid)
            return Error.Validation(validation.Errors[0].ErrorCode,
                validation.Errors[0].ErrorMessage);

        var ticket = SupportTicket.Create(userId, request.Type,
            request.Priority ?? "MEDIUM", request.BookingId, request.Title,
            request.Description, JsonSerializer.Serialize(attachmentUrls));
        if (ticket.IsFailure) return ticket.Error;

        repository.AddSupportTicket(ticket.Value);

        if (ticket.Value.Type == "SOS" || ticket.Value.Priority == "CRITICAL")
        {
            var notification = Notification.Create(userId, "SOS",
                "Ticket khan cap can xu ly",
                body: $"Ticket {ticket.Value.Id} - {request.Type}",
                data: $"{{\"ticket_id\":\"{ticket.Value.Id}\"}}");
            if (notification.IsSuccess) repository.AddNotification(notification.Value);
        }

        await repository.SaveChangesAsync(ct);
        return SupportResponseMapper.ToResponse(ticket.Value);
    }
}
