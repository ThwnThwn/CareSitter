using CareSitter.Modules.Booking.Application.BookingChat;
using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Booking.Application.Commands.BookingChat;

// Viewing the conversation records an admin audit event.
internal sealed record ViewAdminBookingChatCommand(
    Guid ConversationId,
    string Reason,
    Guid? TicketId)
    : IRequest<Result<BookingChatAdminDetail>>;

internal sealed class ViewAdminBookingChatCommandHandler(IBookingChatAdminService chat)
    : IRequestHandler<ViewAdminBookingChatCommand, Result<BookingChatAdminDetail>>
{
    public Task<Result<BookingChatAdminDetail>> Handle(
        ViewAdminBookingChatCommand request, CancellationToken ct) =>
        chat.GetAsync(request.ConversationId, request.Reason, request.TicketId, ct);
}
