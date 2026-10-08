using System.Collections.Concurrent;
using CareSitter.Contracts.Services;
using Microsoft.AspNetCore.SignalR;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;

namespace CareSitter.Infrastructure.Hubs;

public sealed class RealtimeSessionRegistry
{
    private readonly ConcurrentDictionary<string, Entry> _connections = new();
    internal sealed record Entry(Guid UserId, Guid SessionId, HubCallerContext Context);
    internal IEnumerable<Entry> Entries => _connections.Values.ToArray();
    public void Register(Guid userId, Guid sessionId, HubCallerContext context)
        => _connections[context.ConnectionId] = new Entry(userId, sessionId, context);
    public void Remove(string id) => _connections.TryRemove(id, out _);
    public void DisconnectUser(Guid userId)
    {
        foreach (var entry in Entries.Where(x => x.UserId == userId))
        { Remove(entry.Context.ConnectionId); entry.Context.Abort(); }
    }
}

public sealed class RealtimeSessionWatchdog(RealtimeSessionRegistry registry, IServiceScopeFactory scopes) : BackgroundService
{
    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        while (!stoppingToken.IsCancellationRequested)
        {
            foreach (var entry in registry.Entries)
            {
                try
                {
                    await using var scope = scopes.CreateAsyncScope();
                    var validator = scope.ServiceProvider.GetRequiredService<IAccessSessionValidator>();
                    if (await validator.IsActiveAsync(entry.UserId, entry.SessionId, stoppingToken)) continue;
                }
                catch (OperationCanceledException) when (stoppingToken.IsCancellationRequested) { return; }
                catch (Exception) { /* Fail closed nếu không kiểm được phiên. */ }
                registry.Remove(entry.Context.ConnectionId); entry.Context.Abort();
            }
            try { await Task.Delay(TimeSpan.FromSeconds(5), stoppingToken); }
            catch (OperationCanceledException) when (stoppingToken.IsCancellationRequested) { return; }
        }
    }
}
