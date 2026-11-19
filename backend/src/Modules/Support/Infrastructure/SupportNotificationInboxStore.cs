using CareSitter.Modules.Support.Application;
using Microsoft.EntityFrameworkCore;

namespace CareSitter.Modules.Support.Infrastructure;

internal sealed class SupportNotificationInboxStore(SupportDbContext db) : INotificationInboxStore
{
    public async Task<NotificationInboxPage> ListAsync(Guid userId, int page, int pageSize, CancellationToken ct)
    {
        var offset = (long)(page - 1) * pageSize;
        var rows = await db.Database.SqlQueryRaw<InboxRow>(NotificationInboxSql.List, userId, pageSize, offset)
            .ToListAsync(ct);
        // The totals row survives even when an offset points past the last group.
        var totals = rows[0];
        var items = new List<NotificationInboxItem>();
        var bookingMessages = new Dictionary<Guid, Guid[]>();
        foreach (var row in rows)
        {
            if (row.Id is not { } id) continue;
            var preview = row.SupportBody is { } body && row.SupportSentAt is { } sentAt
                ? NotificationChatPreview.FromMessage("Hỗ trợ CareSitter", null, body, sentAt) : null;
            items.Add(new(id, row.GroupKey!, row.Type!, row.Title!, row.Body, row.Data,
                row.CreatedAt!.Value, row.UnreadCount!.Value, preview));
            if (row.BookingMessageIds is { Length: > 0 } ids)
                bookingMessages[id] = ids.Select(text => Guid.TryParse(text, out var parsed) ? parsed : Guid.Empty)
                    .Where(messageId => messageId != Guid.Empty).ToArray();
        }
        return new(new(items, totals.TotalUnread, offset + items.Count < totals.TotalGroups, totals.Version),
            bookingMessages);
    }

    public Task<int> MarkGroupReadAsync(Guid userId, Guid notificationId, CancellationToken ct) =>
        db.Database.ExecuteSqlRawAsync(NotificationInboxSql.MarkRead,
            new object[] { userId, notificationId, DateTimeOffset.UtcNow }, ct);

    private sealed class InboxRow
    {
        public Guid? Id { get; init; }
        public string? GroupKey { get; init; }
        public string? Type { get; init; }
        public string? Title { get; init; }
        public string? Body { get; init; }
        public string? Data { get; init; }
        public DateTimeOffset? CreatedAt { get; init; }
        public int? UnreadCount { get; init; }
        public string[]? BookingMessageIds { get; init; }
        public string? SupportBody { get; init; }
        public DateTimeOffset? SupportSentAt { get; init; }
        public int TotalGroups { get; init; }
        public int TotalUnread { get; init; }
        public string Version { get; init; } = string.Empty;
    }
}
