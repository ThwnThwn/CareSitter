using CareSitter.Modules.Booking.Application.BookingChat;
using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Booking.Application.Queries.BookingChat;

internal sealed record ResumeBookingChatMessagesQuery(
    Guid BookingId,
    Guid AnchorMessageId,
    string Direction,
    long ScopeVersion,
    int Limit)
    : IRequest<Result<BookingChatMessagesResponse>>;

internal sealed class ResumeBookingChatMessagesQueryHandler(IBookingChatQueries chat)
    : IRequestHandler<ResumeBookingChatMessagesQuery, Result<BookingChatMessagesResponse>>
{
    public Task<Result<BookingChatMessagesResponse>> Handle(
        ResumeBookingChatMessagesQuery request, CancellationToken ct) =>
        chat.ResumeMessagesAsync(request.BookingId, request.AnchorMessageId, request.Direction,
            request.ScopeVersion, request.Limit, ct);
}
