namespace CareSitter.Modules.Support.Domain;

/// <summary>Maps a Booking-owned report to exactly one Support-owned ticket.</summary>
public sealed class BookingChatReportTicketSource
{
    private BookingChatReportTicketSource() { }

    public BookingChatReportTicketSource(Guid reportId, Guid ticketId, DateTimeOffset createdAt)
    {
        ReportId = reportId;
        TicketId = ticketId;
        CreatedAt = createdAt;
    }

    public Guid ReportId { get; private set; }
    public Guid TicketId { get; private set; }
    public DateTimeOffset CreatedAt { get; private set; }
}
