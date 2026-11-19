using System.Globalization;

namespace CareSitter.Modules.Support.Application;

public sealed record NotificationChatPreview(
    string? SenderName, string? SenderAvatarUrl, string Preview, DateTimeOffset SentAt,
    DateTimeOffset? ScheduledStart = null)
{
    internal static NotificationChatPreview FromMessage(string? senderName, string? senderAvatarUrl,
        string body, DateTimeOffset sentAt, DateTimeOffset? scheduledStart = null)
    {
        const int maximumLength = 120;
        var text = string.Join(' ', body.Split((char[]?)null, StringSplitOptions.RemoveEmptyEntries));
        var characters = StringInfo.ParseCombiningCharacters(text);
        var preview = characters.Length <= maximumLength
            ? text
            : text[..characters[maximumLength]].TrimEnd() + "…";
        return new(senderName, senderAvatarUrl, preview, sentAt, scheduledStart);
    }
}
