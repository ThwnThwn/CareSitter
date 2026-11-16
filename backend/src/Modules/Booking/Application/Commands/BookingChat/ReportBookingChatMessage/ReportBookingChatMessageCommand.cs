using CareSitter.Modules.Booking.Application.BookingChat;
using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Booking.Application.Commands.BookingChat;

internal sealed record ReportBookingChatMessageCommand(
    Guid BookingId,
    Guid MessageId,
    BookingChatReportRequest Report)
    : IRequest<Result<BookingChatReportResponse>>;

internal sealed class ReportBookingChatMessageCommandHandler(IBookingChatCommands chat)
    : IRequestHandler<ReportBookingChatMessageCommand, Result<BookingChatReportResponse>>
{
    public Task<Result<BookingChatReportResponse>> Handle(
        ReportBookingChatMessageCommand request, CancellationToken ct) =>
        chat.ReportMessageAsync(request.BookingId, request.MessageId, request.Report, ct);
}
