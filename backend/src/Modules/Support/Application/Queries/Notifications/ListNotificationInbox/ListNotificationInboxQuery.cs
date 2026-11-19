using System.Text.Json;
using CareSitter.Contracts.Services;
using CareSitter.Modules.Support.Application.Commands;
using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Support.Application;

public sealed record ListNotificationInboxQuery(int Page, int PageSize)
    : IRequest<Result<NotificationInboxResponse>>;

internal sealed class ListNotificationInboxQueryHandler(
    INotificationInboxStore store, IBookingChatNotificationReader bookingChat, ICurrentUser currentUser)
    : IRequestHandler<ListNotificationInboxQuery, Result<NotificationInboxResponse>>
{
    public async Task<Result<NotificationInboxResponse>> Handle(
        ListNotificationInboxQuery request, CancellationToken ct)
    {
        if (currentUser.UserId is not { } userId) return SupportErrors.Unauthenticated();
        var page = await store.ListAsync(userId, Math.Max(request.Page, 1),
            Math.Clamp(request.PageSize, 1, 50), ct);
        var inbox = page.Response;
        if (page.BookingMessageIds.Count == 0) return inbox;
        var groups = inbox.Items.Where(item => page.BookingMessageIds.ContainsKey(item.Id))
            .Select(item => ReadGroup(item, page.BookingMessageIds[item.Id])).OfType<BookingChatNotificationGroup>()
            .ToArray();
        var messages = await bookingChat.ReadAsync(groups, ct);
        return inbox with
        {
            Items = inbox.Items.Select(row =>
            {
                if (!messages.TryGetValue(row.Id, out var message)) return row;
                return row with
                {
                    Chat = NotificationChatPreview.FromMessage(message.SenderName, message.SenderAvatarUrl,
                        message.Body, message.SentAt, message.ScheduledStart)
                };
            }).ToArray()
        };
    }

    private static BookingChatNotificationGroup? ReadGroup(NotificationInboxItem item, Guid[] ids)
    {
        if (item.Data is null || ids.Length == 0) return null;
        using var document = JsonDocument.Parse(item.Data);
        var payload = document.RootElement;
        return payload.ValueKind == JsonValueKind.Object
            ? new(item.Id, ReadId(payload, "bookingId"), ReadId(payload, "conversationId"), ids)
            : null;
    }

    private static Guid? ReadId(JsonElement payload, string key) =>
        payload.TryGetProperty(key, out var value) && value.ValueKind == JsonValueKind.String &&
        value.TryGetGuid(out var id) ? id : null;
}
