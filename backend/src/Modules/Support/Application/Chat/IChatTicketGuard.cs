namespace CareSitter.Modules.Support.Application.Chat;

public interface IChatTicketGuard
{
    Task<Guid?> FindConversationIdAsync(Guid ticketId, CancellationToken ct);
}
