namespace CareSitter.Contracts.Services;

public interface IBookingChatNotificationReader
{
    /// <summary>The latest visible notified message per group, keyed by the notification anchor.</summary>
    Task<IReadOnlyDictionary<Guid, BookingChatNotificationDetails>> ReadAsync(
        IReadOnlyCollection<BookingChatNotificationGroup> groups, CancellationToken ct = default);
}
