namespace CareSitter.Contracts.Services;

/// <summary>Support-owned boundary for turning a persisted Booking Chat report into one ticket.</summary>
public interface IBookingChatSupportTicketService
{
    Task<Guid> CreateForBookingChatReportAsync(
        BookingChatReportTicketRequest request, CancellationToken ct = default);

    Task<bool> AreResolvedAsync(
        IReadOnlyCollection<Guid> ticketIds, CancellationToken ct = default);
}

public sealed record BookingChatReportTicketRequest(
    Guid ReportId,
    Guid ReporterUserId,
    Guid BookingId,
    Guid ConversationId,
    Guid MessageId,
    string Reason);
