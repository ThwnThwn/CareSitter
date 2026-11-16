using CareSitter.Modules.Booking.Application.BookingChat;
using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Booking.Application.Commands.BookingChat;

internal sealed record MarkBookingChatReadCommand(
    Guid BookingId,
    BookingChatReadRequest Read)
    : IRequest<Result<BookingChatReadResponse>>;

internal sealed class MarkBookingChatReadCommandHandler(IBookingChatCommands chat)
    : IRequestHandler<MarkBookingChatReadCommand, Result<BookingChatReadResponse>>
{
    public Task<Result<BookingChatReadResponse>> Handle(
        MarkBookingChatReadCommand request, CancellationToken ct) =>
        chat.MarkReadAsync(request.BookingId, request.Read, ct);
}
