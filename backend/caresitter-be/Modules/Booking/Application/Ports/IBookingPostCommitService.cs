namespace CareSitter.Modules.Booking.Application;

internal interface IBookingPostCommitService
{
    Task RunAsync(string action, Func<Task> operation);
    Task BroadcastStatusAsync(
        Guid bookingId, string oldStatus, string newStatus, CancellationToken ct);
    Task BroadcastAcceptedStatusAsync(
        Domain.Booking booking, string oldStatus, CancellationToken ct);
    Task PublishCustomerSyncEventAsync(Domain.Booking booking, CancellationToken ct);
    Task NotifyBookingUserAsync(
        Guid userId, Domain.Booking booking, string title, string body, CancellationToken ct);
    Task NotifyCaregiverAsync(
        Domain.Booking booking, string title, string body, CancellationToken ct);
    Task NotifySosTargetsAsync(
        Domain.Booking booking, Guid raisedByUserId, CancellationToken ct);
    Task PublishOfferChangedAsync(
        Guid caregiverId, Guid bookingId, string changeType, CancellationToken ct);
}
