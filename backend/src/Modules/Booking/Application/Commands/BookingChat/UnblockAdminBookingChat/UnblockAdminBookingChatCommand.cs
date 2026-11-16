using CareSitter.Modules.Booking.Application.BookingChat;
using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Booking.Application.Commands.BookingChat;

internal sealed record UnblockAdminBookingChatCommand(
    Guid ConversationId,
    BookingChatAdminBlockRequest Unblock)
    : IRequest<Result<BookingChatAdminDetail>>;

internal sealed class UnblockAdminBookingChatCommandHandler(IBookingChatAdminService chat)
    : IRequestHandler<UnblockAdminBookingChatCommand, Result<BookingChatAdminDetail>>
{
    public Task<Result<BookingChatAdminDetail>> Handle(
        UnblockAdminBookingChatCommand request, CancellationToken ct) =>
        chat.UnblockAsync(request.ConversationId, request.Unblock, ct);
}
