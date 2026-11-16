using CareSitter.Modules.Booking.Application.BookingChat;
using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Booking.Application.Commands.BookingChat;

// Viewing message contents records an admin audit event.
internal sealed record ViewAdminBookingChatMessagesCommand(
    Guid ConversationId,
    long? BeforeSequence,
    int Limit,
    string Reason,
    Guid? TicketId)
    : IRequest<Result<BookingChatAdminMessagePage>>;

internal sealed class ViewAdminBookingChatMessagesCommandHandler(IBookingChatAdminService chat)
    : IRequestHandler<ViewAdminBookingChatMessagesCommand, Result<BookingChatAdminMessagePage>>
{
    public Task<Result<BookingChatAdminMessagePage>> Handle(
        ViewAdminBookingChatMessagesCommand request, CancellationToken ct) =>
        chat.GetMessagesAsync(request.ConversationId, request.BeforeSequence, request.Limit,
            request.Reason, request.TicketId, ct);
}
