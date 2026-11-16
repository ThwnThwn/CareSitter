using CareSitter.Modules.Booking.Application.BookingChat;
using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Booking.Application.Commands.BookingChat;

internal sealed record SendBookingChatMessageCommand(
    Guid BookingId,
    Guid IdempotencyKey,
    BookingChatSendRequest Message)
    : IRequest<Result<BookingChatMessageResponse>>;

internal sealed class SendBookingChatMessageCommandHandler(IBookingChatCommands chat)
    : IRequestHandler<SendBookingChatMessageCommand, Result<BookingChatMessageResponse>>
{
    public Task<Result<BookingChatMessageResponse>> Handle(
        SendBookingChatMessageCommand request, CancellationToken ct) =>
        chat.SendAsync(request.BookingId, request.IdempotencyKey, request.Message, ct);
}
