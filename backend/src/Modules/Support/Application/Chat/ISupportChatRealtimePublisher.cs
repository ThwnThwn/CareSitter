using CareSitter.Modules.Support.Domain;

namespace CareSitter.Modules.Support.Application.Chat;

internal interface ISupportChatRealtimePublisher
{
    Task ConversationCreatedAsync(ChatConversation conversation, SupportTicket ticket);
    Task MessageCreatedAsync(ChatConversation conversation, SupportTicket ticket, ChatMessage message);
    Task ReadCursorChangedAsync(ChatConversation conversation, SupportTicket ticket, Guid userId, long sequence);
    Task ConversationChangedAsync(ChatConversation conversation, SupportTicket ticket, string action);
}
