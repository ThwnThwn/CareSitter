using CareSitter.SharedKernel.Results;

namespace CareSitter.Modules.Support.Application.Chat;

internal static class SupportChatErrors
{
    public static readonly Error Missing = Error.NotFound("support.chat.not_found", "Không tìm thấy hội thoại.");
    public static readonly Error Disabled = Error.Unavailable("support.chat.disabled", "Chat hỗ trợ đang tạm dừng.");

    public static Error Invalid(string message) => Error.Validation("support.chat.invalid_request", message);
    public static Error Conflict(string suffix, string message) =>
        Error.Conflict($"support.chat.{suffix}", message);
}
