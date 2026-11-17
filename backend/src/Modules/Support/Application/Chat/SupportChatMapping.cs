using CareSitter.Modules.Support.Domain;

namespace CareSitter.Modules.Support.Application.Chat;

internal static class SupportChatMapping
{
    public static ChatMessageResponse ToMessage(ChatMessage message, Guid actorId, bool replayed = false) =>
        new(message.Id, message.ConversationId, message.Sequence, message.SenderUserId,
            message.SenderRole, message.Body, message.CreatedAt,
            message.SenderUserId == actorId ? message.IdempotencyKey : null, replayed);
}
