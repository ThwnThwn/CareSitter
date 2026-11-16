using CareSitter.Modules.Support.Application.Chat;
using CareSitter.Modules.Support.Domain;
using Microsoft.EntityFrameworkCore;

namespace CareSitter.Modules.Support.Infrastructure;

internal sealed class SupportChatResponses(SupportDbContext db)
{
    public async Task<ChatConversationResponse> ToConversationAsync(ChatConversation conversation,
        ChatActor actor, CancellationToken ct)
    {
        var ticket = await db.SupportTickets.AsNoTracking().SingleAsync(x => x.Id == conversation.TicketId, ct);
        var ownRead = await db.ChatReadCursors.AsNoTracking().Where(x =>
            x.ConversationId == conversation.Id && x.UserId == actor.UserId)
            .Select(x => (long?)x.LastReadSequence).SingleOrDefaultAsync(ct) ?? 0;
        var unread = await db.ChatMessages.AsNoTracking().CountAsync(x =>
            x.ConversationId == conversation.Id && x.SenderUserId != actor.UserId &&
            x.Sequence > ownRead, ct);
        return new ChatConversationResponse(conversation.Id, ticket.Id,
            conversation.OwnerUserId, ticket.BookingId, ticket.Title, ticket.Status,
            ticket.AssignedAdminId, ticket.Version, conversation.Version,
            conversation.LastSequence, ownRead, conversation.StaffLastReadSequence,
            unread, conversation.CreatedAt, conversation.ClosedAt);
    }

    public static ChatMessageResponse ToMessage(ChatMessage message, Guid actorId, bool replayed = false) =>
        new(message.Id, message.ConversationId, message.Sequence, message.SenderUserId,
            message.SenderRole, message.Body, message.CreatedAt,
            message.SenderUserId == actorId ? message.IdempotencyKey : null, replayed);
}
