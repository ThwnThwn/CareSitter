namespace CareSitter.Modules.Support.Application.Chat;

internal interface ISupportChatTransaction : IAsyncDisposable
{
    Task CommitAsync(CancellationToken ct);
}
