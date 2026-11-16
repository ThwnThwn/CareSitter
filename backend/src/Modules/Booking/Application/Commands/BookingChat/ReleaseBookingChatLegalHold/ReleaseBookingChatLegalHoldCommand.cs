using CareSitter.Modules.Booking.Application.BookingChat;
using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Booking.Application.Commands.BookingChat;

internal sealed record ReleaseBookingChatLegalHoldCommand(
    Guid ConversationId,
    BookingChatAdminBlockRequest Release)
    : IRequest<Result<BookingChatAdminDetail>>;

internal sealed class ReleaseBookingChatLegalHoldCommandHandler(IBookingChatAdminService chat)
    : IRequestHandler<ReleaseBookingChatLegalHoldCommand, Result<BookingChatAdminDetail>>
{
    public Task<Result<BookingChatAdminDetail>> Handle(
        ReleaseBookingChatLegalHoldCommand request, CancellationToken ct) =>
        chat.ReleaseLegalHoldAsync(request.ConversationId, request.Release, ct);
}
