using CareSitter.Modules.Booking.Application.BookingChat;
using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Booking.Application.Commands.BookingChat;

internal sealed record BlockAdminBookingChatCommand(
    Guid ConversationId,
    BookingChatAdminBlockRequest Block)
    : IRequest<Result<BookingChatAdminDetail>>;

internal sealed class BlockAdminBookingChatCommandHandler(IBookingChatAdminService chat)
    : IRequestHandler<BlockAdminBookingChatCommand, Result<BookingChatAdminDetail>>
{
    public Task<Result<BookingChatAdminDetail>> Handle(
        BlockAdminBookingChatCommand request, CancellationToken ct) =>
        chat.BlockAsync(request.ConversationId, request.Block, ct);
}
