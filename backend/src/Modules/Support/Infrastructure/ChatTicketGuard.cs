using CareSitter.Modules.Support.Application.Chat;
using Microsoft.EntityFrameworkCore;

namespace CareSitter.Modules.Support.Infrastructure;

internal sealed class ChatTicketGuard(SupportDbContext db) : IChatTicketGuard
{
    public Task<Guid?> FindConversationIdAsync(Guid ticketId, CancellationToken ct) =>
        db.ChatConversations.AsNoTracking().Where(x => x.TicketId == ticketId)
            .Select(x => (Guid?)x.Id).SingleOrDefaultAsync(ct);
}
