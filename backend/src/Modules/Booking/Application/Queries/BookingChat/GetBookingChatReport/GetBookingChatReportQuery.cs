using CareSitter.Modules.Booking.Application.BookingChat;
using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Booking.Application.Queries.BookingChat;

internal sealed record GetBookingChatReportQuery(
    Guid BookingId,
    Guid ReportId)
    : IRequest<Result<BookingChatReportResponse>>;

internal sealed class GetBookingChatReportQueryHandler(IBookingChatQueries chat)
    : IRequestHandler<GetBookingChatReportQuery, Result<BookingChatReportResponse>>
{
    public Task<Result<BookingChatReportResponse>> Handle(
        GetBookingChatReportQuery request, CancellationToken ct) =>
        chat.GetReportAsync(request.BookingId, request.ReportId, ct);
}
