using CareSitter.Modules.Booking.Application.BookingChat;
using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Booking.Application.Queries.BookingChat;

internal sealed record GetBookingChatMetadataQuery(Guid BookingId)
    : IRequest<Result<BookingChatMetadataResponse>>;

internal sealed class GetBookingChatMetadataQueryHandler(IBookingChatQueries chat)
    : IRequestHandler<GetBookingChatMetadataQuery, Result<BookingChatMetadataResponse>>
{
    public Task<Result<BookingChatMetadataResponse>> Handle(
        GetBookingChatMetadataQuery request, CancellationToken ct) =>
        chat.GetMetadataAsync(request.BookingId, ct);
}
