namespace CareSitter.Modules.Support.Domain;

public interface ISupportRepository
{
    Task<bool> DisputeExistsAsync(Guid bookingId, CancellationToken ct = default);
    Task<Dispute?> GetDisputeAsync(Guid id, CancellationToken ct = default);
    void AddDispute(Dispute dispute);

    Task<Notification?> GetNotificationAsync(Guid id, Guid userId, CancellationToken ct = default);
    Task<List<Notification>> GetUnreadNotificationsAsync(Guid userId, CancellationToken ct = default);
    void AddNotification(Notification notification);

    Task<bool> ReviewExistsAsync(Guid bookingId, CancellationToken ct = default);
    Task<bool> TryAddReviewAsync(Review review, CancellationToken ct = default);

    Task<SupportTicket?> GetSupportTicketAsync(Guid id, CancellationToken ct = default);
    void AddSupportTicket(SupportTicket ticket);

    Task SaveChangesAsync(CancellationToken ct = default);
}
