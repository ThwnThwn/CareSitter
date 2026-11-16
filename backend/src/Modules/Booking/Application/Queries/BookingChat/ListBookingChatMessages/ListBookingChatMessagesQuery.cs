using CareSitter.Modules.Booking.Application.BookingChat;
using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Booking.Application.Queries.BookingChat;

internal sealed record ListBookingChatMessagesQuery(
    Guid BookingId,
    string? AfterCursor,
    string? BeforeCursor,
    int Limit)
    : IRequest<Result<BookingChatMessagesResponse>>;

internal sealed class ListBookingChatMessagesQueryHandler(IBookingChatQueries chat)
    : IRequestHandler<ListBookingChatMessagesQuery, Result<BookingChatMessagesResponse>>
{
    public Task<Result<BookingChatMessagesResponse>> Handle(
        ListBookingChatMessagesQuery request, CancellationToken ct) =>
        chat.GetMessagesAsync(request.BookingId, request.AfterCursor, request.BeforeCursor, request.Limit, ct);
}
