using CareSitter.Modules.Booking.Application;
using CareSitter.Modules.Booking.Domain;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;

namespace CareSitter.Modules.Booking.Infrastructure;

internal sealed class BookingChatWriter(
    BookingDbContext db,
    IOptions<BookingChatOptions> options) : IBookingChatWriter
{
    private readonly BookingChatOptions _options = options.Value;

    public async Task EnsureFirstEpochAsync(Domain.Booking booking, Guid caregiverUserId,
        DateTimeOffset occurredAt, CancellationToken ct = default)
    {
        if (!_options.Enabled) return;
        if (booking.CaregiverId is not { } caregiverProfileId)
            throw new InvalidOperationException("Booking chat requires an assigned caregiver.");

        var tracked = db.BookingChatConversations.Local
            .SingleOrDefault(x => x.BookingId == booking.Id);
        if (tracked is not null || await db.BookingChatConversations
                .AnyAsync(x => x.BookingId == booking.Id, ct))
            return;

        var conversation = BookingChatConversation.Create(booking.Id, occurredAt);
        var epoch = BookingChatEpoch.CreateFirst(conversation.Id, caregiverProfileId,
            caregiverUserId, occurredAt);
        var sourceEventId = BookingChatSourceEventIds.Create(booking.Id, booking.SyncVersion,
            BookingSyncEventTypes.CaregiverAccepted);
        var message = BookingChatMessage.CreateSystem(conversation.Id, epoch.Id,
            1, sourceEventId, "Caregiver đã nhận lịch.", occurredAt);

        db.BookingChatConversations.Add(conversation);
        db.BookingChatEpochs.Add(epoch);
        db.BookingChatMessages.Add(message);
        db.BookingChatOutbox.AddRange(
            BookingChatOutboxEvent.Create(conversation.Id, epoch.Id, booking.CustomerId,
                message.Id, "SYSTEM_MESSAGE_CREATED", 1, occurredAt),
            BookingChatOutboxEvent.Create(conversation.Id, epoch.Id, caregiverUserId,
                message.Id, "SYSTEM_MESSAGE_CREATED", 1, occurredAt));
    }

    public async Task RecordSystemTransitionAsync(Domain.Booking booking,
        string sourceEventType, string bodySnapshot, DateTimeOffset occurredAt,
        BookingChatTransitionEffect effect = BookingChatTransitionEffect.None,
        CancellationToken ct = default)
    {
        if (!_options.Enabled) return;

        var conversation = db.BookingChatConversations.Local
            .SingleOrDefault(x => x.BookingId == booking.Id) ??
            await db.BookingChatConversations.SingleOrDefaultAsync(
                x => x.BookingId == booking.Id, ct);
        if (conversation is null || conversation.PurgedAt is not null) return;

        var epoch = await db.BookingChatEpochs
            .SingleOrDefaultAsync(x => x.ConversationId == conversation.Id && x.EndedAt == null, ct);
        if (epoch is null) return;

        var sourceEventId = BookingChatSourceEventIds.Create(booking.Id, booking.SyncVersion, sourceEventType);
        if (await db.BookingChatMessages.AnyAsync(
                x => x.ConversationId == conversation.Id && x.SourceEventId == sourceEventId, ct))
            return;

        if (effect.HasFlag(BookingChatTransitionEffect.StartPostShiftGrace))
            conversation.SnapshotGraceWindow(occurredAt,
                TimeSpan.FromHours(_options.PostShiftGraceHours));
        if (effect.HasFlag(BookingChatTransitionEffect.LockForDispute))
            conversation.LockForDispute(occurredAt);
        if (effect.HasFlag(BookingChatTransitionEffect.ScheduleRetention))
            conversation.ScheduleRetention(occurredAt,
                TimeSpan.FromDays(_options.RetentionDays));

        var next = conversation.AppendMessage(occurredAt);
        var message = BookingChatMessage.CreateSystem(conversation.Id, epoch.Id,
            next.Sequence, sourceEventId, bodySnapshot, occurredAt);
        db.BookingChatMessages.Add(message);
        db.BookingChatOutbox.AddRange(
            BookingChatOutboxEvent.Create(conversation.Id, epoch.Id, booking.CustomerId,
                message.Id, "SYSTEM_MESSAGE_CREATED", next.ChangeVersion, occurredAt),
            BookingChatOutboxEvent.Create(conversation.Id, epoch.Id, epoch.CaregiverUserId,
                message.Id, "SYSTEM_MESSAGE_CREATED", next.ChangeVersion, occurredAt));
    }
}
