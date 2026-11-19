namespace CareSitter.Modules.Support.Application;

internal interface INotificationInboxStore
{
    Task<NotificationInboxPage> ListAsync(Guid userId, int page, int pageSize, CancellationToken ct);
    Task<int> MarkGroupReadAsync(Guid userId, Guid notificationId, CancellationToken ct);
}
