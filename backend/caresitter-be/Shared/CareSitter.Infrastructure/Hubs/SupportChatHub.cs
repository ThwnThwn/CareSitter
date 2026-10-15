using System.Security.Claims;
using System.Diagnostics.Metrics;
using CareSitter.Contracts.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.SignalR;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;

namespace CareSitter.Infrastructure.Hubs;

[Authorize]
public sealed class SupportChatHub(IServiceScopeFactory scopes, IConfiguration configuration) : Hub
{
    private static readonly Meter Meter = new("CareSitter.SupportChat.Hub");
    private static readonly Counter<long> Connections = Meter.CreateCounter<long>("support_chat_hub_connections_total");
    private static readonly Counter<long> JoinDenied = Meter.CreateCounter<long>("support_chat_hub_join_denied_total");
    public const string AdminQueueGroup = "support-chat-admin-queue";
    public static string ConversationGroup(Guid id) => $"support-chat-{id:D}";
    public static string OwnerGroup(Guid id) => $"support-chat-owner-{id:D}";

    public override async Task OnConnectedAsync()
    {
        if (!configuration.GetValue<bool>("SupportChat:Enabled")) { Context.Abort(); return; }
        if (!TryIdentity(out var userId, out var sessionId)) { Context.Abort(); return; }
        await using var scope = scopes.CreateAsyncScope();
        var valid = await scope.ServiceProvider.GetRequiredService<IAccessSessionValidator>()
            .IsActiveAsync(userId, sessionId, Context.ConnectionAborted);
        if (!valid) { Context.Abort(); return; }
        scope.ServiceProvider.GetService<RealtimeSessionRegistry>()?.Register(userId, sessionId, Context);
        if (Context.User?.IsInRole("ADMIN") == true)
        {
            var admins = scope.ServiceProvider.GetRequiredService<IActiveAdminLookup>();
            if (!await admins.IsActiveAdminAsync(userId, Context.ConnectionAborted))
            { Context.Abort(); return; }
            await Groups.AddToGroupAsync(Context.ConnectionId, AdminQueueGroup);
            Connections.Add(1, new KeyValuePair<string, object?>("role", "ADMIN"));
        }
        else if (Context.User?.IsInRole("CUSTOMER") == true ||
                 Context.User?.IsInRole("CAREGIVER") == true)
        {
            await Groups.AddToGroupAsync(Context.ConnectionId, OwnerGroup(userId));
            Connections.Add(1, new KeyValuePair<string, object?>("role",
                Context.User.IsInRole("CAREGIVER") ? "CAREGIVER" : "CUSTOMER"));
        }
        else { Context.Abort(); return; }
        await base.OnConnectedAsync();
    }

    public async Task<string> JoinConversation(Guid conversationId)
    {
        if (!configuration.GetValue<bool>("SupportChat:Enabled")) return "disabled";
        if (!TryIdentity(out var userId, out var sessionId)) return "unauthorized";
        await using var scope = scopes.CreateAsyncScope();
        if (!await scope.ServiceProvider.GetRequiredService<IAccessSessionValidator>()
            .IsActiveAsync(userId, sessionId, Context.ConnectionAborted))
        { Context.Abort(); return "unauthorized"; }
        var canRead = await scope.ServiceProvider.GetRequiredService<ISupportChatMembership>()
            .CanReadAsync(conversationId, userId, Context.User?.IsInRole("ADMIN") == true,
                Context.ConnectionAborted);
        if (!canRead) { JoinDenied.Add(1); return "unauthorized"; }
        await Groups.AddToGroupAsync(Context.ConnectionId, ConversationGroup(conversationId));
        return "ok";
    }

    public Task LeaveConversation(Guid conversationId) =>
        Groups.RemoveFromGroupAsync(Context.ConnectionId, ConversationGroup(conversationId));

    public override async Task OnDisconnectedAsync(Exception? exception)
    {
        await using var scope = scopes.CreateAsyncScope();
        scope.ServiceProvider.GetService<RealtimeSessionRegistry>()?.Remove(Context.ConnectionId);
        await base.OnDisconnectedAsync(exception);
    }

    private bool TryIdentity(out Guid userId, out Guid sessionId)
    {
        var rawUserId = Context.User?.FindFirst(ClaimTypes.NameIdentifier)?.Value
            ?? Context.User?.FindFirst("sub")?.Value;
        var validUser = Guid.TryParse(rawUserId, out userId);
        var validSession = Guid.TryParse(Context.User?.FindFirst("sid")?.Value, out sessionId);
        return validUser && validSession;
    }
}
