using CareSitter.Modules.Booking.Application.BookingChat;
using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Booking.Application.Queries.BookingChat;

internal sealed record ListAdminBookingChatsQuery(
    BookingChatAdminListFilter Filter,
    string? Cursor,
    int Limit)
    : IRequest<Result<BookingChatAdminListPage>>;

internal sealed class ListAdminBookingChatsQueryHandler(IBookingChatAdminService chat)
    : IRequestHandler<ListAdminBookingChatsQuery, Result<BookingChatAdminListPage>>
{
    public Task<Result<BookingChatAdminListPage>> Handle(
        ListAdminBookingChatsQuery request, CancellationToken ct) =>
        chat.ListAsync(request.Filter, request.Cursor, request.Limit, ct);
}
