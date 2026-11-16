using CareSitter.Modules.Booking.Application.BookingChat;
using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Booking.Application.Commands.BookingChat;

internal sealed record SetBookingChatBlockCommand(
    Guid BookingId,
    BookingChatBlockRequest Block)
    : IRequest<Result<BookingChatBlockResponse>>;

internal sealed class SetBookingChatBlockCommandHandler(IBookingChatCommands chat)
    : IRequestHandler<SetBookingChatBlockCommand, Result<BookingChatBlockResponse>>
{
    public Task<Result<BookingChatBlockResponse>> Handle(
        SetBookingChatBlockCommand request, CancellationToken ct) =>
        chat.SetBlockAsync(request.BookingId, request.Block, ct);
}
