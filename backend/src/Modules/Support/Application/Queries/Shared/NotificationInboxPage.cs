namespace CareSitter.Modules.Support.Application;

internal sealed record NotificationInboxPage(
    NotificationInboxResponse Response, IReadOnlyDictionary<Guid, Guid[]> BookingMessageIds);
