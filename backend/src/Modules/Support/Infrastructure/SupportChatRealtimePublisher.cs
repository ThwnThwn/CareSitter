using CareSitter.Modules.Support.Application.Chat;
using CareSitter.Infrastructure.Hubs;
using CareSitter.Modules.Support.Domain;
using Microsoft.AspNetCore.SignalR;
using Microsoft.Extensions.Logging;

namespace CareSitter.Modules.Support.Infrastructure;

internal sealed class SupportChatRealtimePublisher(
    IHubContext<SupportChatHub> hub, ILogger<SupportChatRealtimePublisher> logger,
    SupportChatMetrics? metrics = null) : ISupportChatRealtimePublisher
{
    public Task ConversationCreatedAsync(ChatConversation conversation, SupportTicket ticket) =>
        PublishQueueChangedAsync(conversation, ticket, "CREATED");

    public async Task MessageCreatedAsync(
        ChatConversation conversation, SupportTicket ticket, ChatMessage message)
    {
        await SignalAsync(SupportChatHub.ConversationGroup(conversation.Id), "MessageCreated", new
        {
            eventId = message.Id, conversationId = conversation.Id, messageId = message.Id,
            sequence = message.Sequence, createdAt = message.CreatedAt
        });
        await PublishConversationChangedAsync(SupportChatHub.OwnerGroup(conversation.OwnerUserId),
            conversation, ticket);
        await PublishQueueChangedAsync(conversation, ticket, "MESSAGE_CREATED");
    }

    public async Task ReadCursorChangedAsync(
        ChatConversation conversation, SupportTicket ticket, Guid userId, long sequence)
    {
        await SignalAsync(SupportChatHub.OwnerGroup(userId), "ReadCursorChanged", new
        {
            conversationId = conversation.Id, userId, lastReadSequence = sequence
        });
        await PublishConversationChangedAsync(SupportChatHub.ConversationGroup(conversation.Id),
            conversation, ticket);
    }

    public async Task ConversationChangedAsync(
        ChatConversation conversation, SupportTicket ticket, string action)
    {
        await PublishConversationChangedAsync(SupportChatHub.ConversationGroup(conversation.Id),
            conversation, ticket);
        await PublishConversationChangedAsync(SupportChatHub.OwnerGroup(conversation.OwnerUserId),
            conversation, ticket);
        await PublishQueueChangedAsync(conversation, ticket, action);
    }

    private Task PublishConversationChangedAsync(
        string group, ChatConversation conversation, SupportTicket ticket) =>
        SignalAsync(group, "ConversationChanged", new
        {
            conversationId = conversation.Id, ticketStatus = ticket.Status, assignedAdminId = ticket.AssignedAdminId,
            ticketVersion = ticket.Version, conversationVersion = conversation.Version
        });

    private Task PublishQueueChangedAsync(
        ChatConversation conversation, SupportTicket ticket, string action) =>
        SignalAsync(SupportChatHub.AdminQueueGroup, "AdminQueueChanged", new
        {
            conversationId = conversation.Id, changeType = action,
            ticketVersion = ticket.Version, conversationVersion = conversation.Version
        });

    private async Task SignalAsync(string group, string eventName, object payload)
    {
        try
        {
            await hub.Clients.Group(group).SendCoreAsync(eventName, [payload]);
        }
        catch (Exception ex)
        {
            metrics?.FanoutFailure(eventName);
            logger.LogWarning(ex, "Support chat realtime signal failed for {EventName}", eventName);
        }
    }
}
