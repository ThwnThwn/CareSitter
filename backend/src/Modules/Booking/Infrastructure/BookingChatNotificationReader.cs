using CareSitter.Contracts.Services;
using Microsoft.EntityFrameworkCore;

namespace CareSitter.Modules.Booking.Infrastructure;

internal sealed class BookingChatNotificationReader(
    BookingDbContext db,
    ICurrentUser currentUser,
    IPeopleLookupService people,
    IUserProfileReader profiles) : IBookingChatNotificationReader
{
    public async Task<IReadOnlyDictionary<Guid, BookingChatNotificationDetails>> ReadAsync(
        IReadOnlyCollection<BookingChatNotificationGroup> groups, CancellationToken ct = default)
    {
        if (currentUser.UserId is not { } userId || groups.Count == 0)
            return new Dictionary<Guid, BookingChatNotificationDetails>();

        var isCustomer = currentUser.IsInRole("CUSTOMER");
        var caregiverId = currentUser.IsInRole("CAREGIVER")
            ? await people.GetCaregiverProfileIdByUserIdAsync(userId, ct)
            : null;

        // The same conversation can have legacy groups with different routing keys.
        // Keep membership and scope attached to the message before ranking by sequence.
        var refs = groups.SelectMany(g => g.MessageIds.Select(id => new { g.Anchor, g.BookingId, g.ConversationId, Id = id })).ToArray();
        var candidates = db.Database.SqlQuery<MessageReference>($"""
            SELECT * FROM unnest({refs.Select(r => r.Anchor).ToArray()}::uuid[],
                {refs.Select(r => r.BookingId).ToArray()}::uuid[], {refs.Select(r => r.ConversationId).ToArray()}::uuid[],
                {refs.Select(r => r.Id).ToArray()}::uuid[]) AS r("Anchor", "BookingId", "ConversationId", "MessageId")
            """);
        var eligible =
            from candidate in candidates
            join message in db.BookingChatMessages.AsNoTracking() on candidate.MessageId equals message.Id
            join conversation in db.BookingChatConversations on message.ConversationId equals conversation.Id
            join booking in db.Bookings on conversation.BookingId equals booking.Id
            join epoch in db.BookingChatEpochs on message.EpochId equals epoch.Id
            where (candidate.BookingId == null || candidate.BookingId == booking.Id) &&
                (candidate.ConversationId == null || candidate.ConversationId == conversation.Id) &&
                conversation.PurgedAt == null &&
                message.SenderUserId != null && message.SenderUserId != userId &&
                ((isCustomer && booking.CustomerId == userId) ||
                 (caregiverId != null && booking.CaregiverId == caregiverId &&
                  epoch.CaregiverProfileId == caregiverId && epoch.CaregiverUserId == userId &&
                  epoch.EndedAt == null))
            select new
            {
                candidate.Anchor, message.ConversationId, message.Sequence, SenderId = message.SenderUserId!.Value,
                message.BodySnapshot, message.CreatedAt, BookingId = booking.Id, booking.ScheduledStart
            };
        var messages = await eligible.GroupBy(message => message.Anchor)
            .Select(group => group.OrderByDescending(message => message.Sequence).First()).ToListAsync(ct);

        if (messages.Count == 0) return new Dictionary<Guid, BookingChatNotificationDetails>();

        var senders = await profiles.GetDisplayProfilesAsync(
            messages.Select(x => x.SenderId).Distinct().ToArray(), ct);
        return messages.ToDictionary(x => x.Anchor, x =>
        {
            var sender = senders.GetValueOrDefault(x.SenderId);
            return new BookingChatNotificationDetails(x.BookingId, x.ConversationId,
                sender?.Name, sender?.AvatarUrl, x.BodySnapshot, x.CreatedAt, x.ScheduledStart);
        });
    }

    private sealed record MessageReference(Guid Anchor, Guid? BookingId, Guid? ConversationId, Guid MessageId);
}
