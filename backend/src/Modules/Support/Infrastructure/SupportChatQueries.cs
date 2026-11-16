using CareSitter.Contracts.Services;
using CareSitter.Modules.Support.Application.Chat;
using CareSitter.Modules.Support.Domain;
using CareSitter.SharedKernel.Results;
using Microsoft.EntityFrameworkCore;
using static CareSitter.Modules.Support.Application.Chat.SupportChatErrors;

namespace CareSitter.Modules.Support.Infrastructure;

internal sealed class SupportChatQueries(
    SupportDbContext db, IActiveAdminLookup admins, SupportChatResponses responses)
    : ISupportChatQueries
{
    public async Task<Result<ChatListResponse>> ListAsync(ChatActor actor, string? queue,
        DateTimeOffset? beforeCreatedAt, Guid? beforeId, int limit, CancellationToken ct)
    {
        if (beforeCreatedAt.HasValue != beforeId.HasValue)
            return Invalid("Cursor hội thoại không hợp lệ.");
        if (actor.IsAdmin && !await admins.IsActiveAdminAsync(actor.UserId, ct))
            return Error.Forbidden("support.chat.forbidden", "Tài khoản Admin không hoạt động.");
        limit = Math.Clamp(limit, 1, 50);
        var query = db.ChatConversations.AsNoTracking()
            .Join(db.SupportTickets.AsNoTracking(), c => c.TicketId, t => t.Id,
                (c, t) => new { c, t });
        if (actor.IsAdmin)
        {
            query = queue?.ToLowerInvariant() switch
            {
                "new" => query.Where(x => x.t.Status == "NEW"),
                "mine" => query.Where(x => x.t.AssignedAdminId == actor.UserId && x.t.Status == "IN_PROGRESS"),
                "active" => query.Where(x => x.t.Status == "NEW" || x.t.Status == "IN_PROGRESS"),
                "closed" => query.Where(x => x.t.Status == "RESOLVED" || x.t.Status == "CLOSED"),
                null or "" => query,
                _ => query.Where(x => false)
            };
        }
        else query = query.Where(x => x.c.OwnerUserId == actor.UserId);
        if (beforeCreatedAt is { } before && beforeId is { } tie)
            query = query.Where(x => x.c.CreatedAt < before ||
                (x.c.CreatedAt == before && x.c.Id.CompareTo(tie) < 0));
        var rows = await query.OrderByDescending(x => x.c.CreatedAt).ThenByDescending(x => x.c.Id)
            .Take(limit + 1).Select(x => x.c).ToListAsync(ct);
        var items = new List<ChatConversationResponse>();
        foreach (var row in rows.Take(limit)) items.Add(await responses.ToConversationAsync(row, actor, ct));
        var last = rows.Take(limit).LastOrDefault();
        return new ChatListResponse(items, rows.Count > limit, last?.CreatedAt, last?.Id);
    }

    public async Task<Result<ChatConversationResponse>> GetAsync(ChatActor actor, Guid id, CancellationToken ct)
    {
        var conversation = await VisibleAsync(actor, id, ct);
        return conversation is null ? Missing : await responses.ToConversationAsync(conversation, actor, ct);
    }

    public async Task<Result<ChatPageResponse<ChatMessageResponse>>> MessagesAsync(ChatActor actor, Guid id,
        long? before, long? after, long? highWatermark, int limit, CancellationToken ct)
    {
        if (before is <= 0 || after is < 0 || highWatermark is < 0 ||
            (before.HasValue && after.HasValue)) return Invalid("Cursor không hợp lệ.");
        var conversation = await VisibleAsync(actor, id, ct);
        if (conversation is null) return Missing;
        limit = Math.Clamp(limit, 1, 100);
        var ceiling = Math.Min(highWatermark ?? conversation.LastSequence, conversation.LastSequence);
        var query = db.ChatMessages.AsNoTracking().Where(x =>
            x.ConversationId == id && x.Sequence <= ceiling);
        if (before is { } b) query = query.Where(x => x.Sequence < b);
        if (after is { } a) query = query.Where(x => x.Sequence > a);
        var rows = after.HasValue
            ? await query.OrderBy(x => x.Sequence).Take(limit + 1).ToListAsync(ct)
            : await query.OrderByDescending(x => x.Sequence).Take(limit + 1).ToListAsync(ct);
        var page = rows.Take(limit).OrderBy(x => x.Sequence).ToArray();
        return new ChatPageResponse<ChatMessageResponse>(
            page.Select(x => SupportChatResponses.ToMessage(x, actor.UserId)).ToArray(), rows.Count > limit,
            page.Length == 0 ? null : page[0].Sequence,
            page.Length == 0 ? after : page[^1].Sequence, ceiling);
    }

    public async Task<Result<ChatActivityListResponse>> ActivitiesAsync(ChatActor actor,
        Guid id, DateTimeOffset? beforeCreatedAt, Guid? beforeId, int limit,
        CancellationToken ct)
    {
        if (beforeCreatedAt.HasValue != beforeId.HasValue)
            return Invalid("Cursor hoạt động không hợp lệ.");
        if (await VisibleAsync(actor, id, ct) is null) return Missing;
        limit = Math.Clamp(limit, 1, 100);
        var q = db.ChatActivityEvents.AsNoTracking().Where(x => x.ConversationId == id);
        if (beforeCreatedAt is { } before && beforeId is { } tie)
            q = q.Where(x => x.CreatedAt < before ||
                (x.CreatedAt == before && x.Id.CompareTo(tie) < 0));
        var rows = await q.OrderByDescending(x => x.CreatedAt).ThenByDescending(x => x.Id)
            .Take(limit + 1).ToListAsync(ct);
        var page = rows.Take(limit).Select(x => new ChatActivityResponse(x.Id, x.Action,
            x.FromStatus, x.ToStatus, actor.IsAdmin ? x.FromAdminId : null,
            actor.IsAdmin ? x.ToAdminId : null,
            actor.IsAdmin || x.Action == "STATUS" ? x.Reason : null, x.CreatedAt)).ToArray();
        return new ChatActivityListResponse(page, rows.Count > limit,
            page.Length == 0 ? null : page[^1].CreatedAt,
            page.Length == 0 ? null : page[^1].Id);
    }

    private async Task<ChatConversation?> VisibleAsync(ChatActor actor, Guid id, CancellationToken ct)
    {
        if (actor.IsAdmin && !await admins.IsActiveAdminAsync(actor.UserId, ct)) return null;
        return await db.ChatConversations.AsNoTracking().SingleOrDefaultAsync(x => x.Id == id &&
            (actor.IsAdmin || x.OwnerUserId == actor.UserId), ct);
    }
}
