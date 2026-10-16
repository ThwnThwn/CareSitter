namespace CareSitter.Contracts.Services;

public interface ISupportChatMembership
{
    Task<bool> CanReadAsync(Guid conversationId, Guid userId, bool isAdmin,
        CancellationToken ct = default);
}
