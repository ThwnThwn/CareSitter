using CareSitter.Modules.Booking.Application.BookingChat;
using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Booking.Application.Queries.BookingChat;

internal sealed record ListAdminBookingChatActivitiesQuery(
    Guid ConversationId,
    string? Cursor,
    int Limit)
    : IRequest<Result<BookingChatAdminActivityPage>>;

internal sealed class ListAdminBookingChatActivitiesQueryHandler(IBookingChatAdminService chat)
    : IRequestHandler<ListAdminBookingChatActivitiesQuery, Result<BookingChatAdminActivityPage>>
{
    public Task<Result<BookingChatAdminActivityPage>> Handle(
        ListAdminBookingChatActivitiesQuery request, CancellationToken ct) =>
        chat.GetActivityAsync(request.ConversationId, request.Cursor, request.Limit, ct);
}
