using CareSitter.Modules.Support.Application.Chat;
using Microsoft.EntityFrameworkCore.Storage;

namespace CareSitter.Modules.Support.Infrastructure;

internal sealed class SupportChatTransaction(IDbContextTransaction transaction) : ISupportChatTransaction
{
    public Task CommitAsync(CancellationToken ct) => transaction.CommitAsync(ct);
    public ValueTask DisposeAsync() => transaction.DisposeAsync();
}
