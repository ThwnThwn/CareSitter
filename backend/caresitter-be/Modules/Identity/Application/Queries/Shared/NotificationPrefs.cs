using CareSitter.SharedKernel.Results;

namespace CareSitter.Modules.Identity.Application;

public sealed class NotificationPrefs
{
    public bool BookingUpdates { get; set; } = true;
    public bool PaymentUpdates { get; set; } = true;
    public bool CaregiverArriving { get; set; } = true;
    public bool ScheduleReminder { get; set; } = true;
    public bool ChatMessage { get; set; } = true;
    public bool SupportChatMessage { get; set; } = true;
    public bool Promotion { get; set; }

    public static NotificationPrefs Parse(string? json)
    {
        if (string.IsNullOrWhiteSpace(json)) return new NotificationPrefs();
        try
        {
            return System.Text.Json.JsonSerializer.Deserialize<NotificationPrefs>(json,
                new System.Text.Json.JsonSerializerOptions { PropertyNameCaseInsensitive = true })
                ?? new NotificationPrefs();
        }
        catch
        {
            return new NotificationPrefs();
        }
    }

    public string ToJson() => System.Text.Json.JsonSerializer.Serialize(this,
        new System.Text.Json.JsonSerializerOptions
        {
            PropertyNamingPolicy = System.Text.Json.JsonNamingPolicy.CamelCase
        });
}
