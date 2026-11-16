using System.Text.Json;
using CareSitter.Modules.Booking.Application.BookingChat;
using CareSitter.Modules.Booking.Domain;

namespace CareSitter.Modules.Booking.Infrastructure;

internal static class BookingChatResponses
{
    public static BookingChatMessageResponse ToMessage(BookingChatMessage message, Guid userId)
    {
        IReadOnlyDictionary<string, string>? parameters = null;
        if (!string.IsNullOrWhiteSpace(message.TemplateParams))
        {
            parameters = JsonSerializer.Deserialize<Dictionary<string, string>>(
                message.TemplateParams!);
        }
        return new(message.Id, message.EpochId, message.Sequence,
            message.SenderUserId, message.SenderRole, message.Kind,
            message.TemplateKey, message.TemplateVersion, parameters,
            message.BodySnapshot, message.CreatedAt, message.SenderUserId == userId);
    }

    public static string ToApi(BookingChatLifecycleState state) => state switch
    {
        BookingChatLifecycleState.PostShiftGrace => "post_shift_grace",
        _ => state.ToString().ToLowerInvariant()
    };

    public static string ToApi(BookingChatLifecycleReason reason) => reason switch
    {
        BookingChatLifecycleReason.None => "none",
        BookingChatLifecycleReason.ConversationNotReady => "conversation_not_ready",
        BookingChatLifecycleReason.CaregiverNotAssigned => "caregiver_not_assigned",
        BookingChatLifecycleReason.BookingState => "booking_state",
        BookingChatLifecycleReason.AdminBlocked => "admin_blocked",
        BookingChatLifecycleReason.DisputeLocked => "dispute_locked",
        BookingChatLifecycleReason.BookingClosed => "booking_closed",
        BookingChatLifecycleReason.GraceDeadlineMissing => "grace_deadline_missing",
        BookingChatLifecycleReason.GraceExpired => "grace_expired",
        _ => reason.ToString().ToLowerInvariant()
    };
}
