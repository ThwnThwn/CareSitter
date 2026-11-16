using System.Globalization;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using CareSitter.Modules.Booking.Application.BookingChat;
using CareSitter.Modules.Booking.Domain;
using CareSitter.SharedKernel.Results;

namespace CareSitter.Modules.Booking.Infrastructure;

internal static class BookingChatMessageContent
{
    private const int MaxBodyBytes = 8192;

    public static Result<PreparedMessage> Prepare(
        BookingChatSendRequest request, string role, BookingStatus status)
    {
        var kind = request.Kind?.Trim().ToLowerInvariant();
        if (kind == "text")
        {
            if (request.TemplateKey is not null || request.TemplateVersion is not null ||
                request.TemplateParams is not null)
                return BookingChatErrors.InvalidRequest("Tin text không được chứa thông tin template.");
            var normalized = (request.Text ?? string.Empty).Trim().Normalize(NormalizationForm.FormC);
            if (string.IsNullOrWhiteSpace(normalized))
                return BookingChatErrors.InvalidRequest("Nội dung tin nhắn không được để trống.");
            if (normalized.EnumerateRunes().Count() > 2000 ||
                Encoding.UTF8.GetByteCount(normalized) > MaxBodyBytes)
                return BookingChatErrors.InvalidRequest("Tin nhắn vượt quá giới hạn 2.000 ký tự.");
            if (normalized.Any(ch => char.IsControl(ch) && ch is not '\r' and not '\n' and not '\t'))
                return BookingChatErrors.InvalidRequest("Tin nhắn chứa ký tự điều khiển không hợp lệ.");
            return new PreparedMessage("text", normalized, null, null, null);
        }

        if (kind != "quick_message" || string.IsNullOrWhiteSpace(request.TemplateKey) ||
            request.TemplateVersion != 1 || request.Text is not null)
            return BookingChatErrors.InvalidRequest("Tin nhắn nhanh không hợp lệ.");
        var available = GetTemplates(role, status);
        var template = available.SingleOrDefault(x => x.Key == request.TemplateKey);
        if (template is null)
            return BookingChatErrors.InvalidRequest("Mẫu tin nhắn không khả dụng ở trạng thái hiện tại.");

        var parameters = new SortedDictionary<string, string>(StringComparer.Ordinal);
        if (request.TemplateParams is not null)
        {
            foreach (var parameter in request.TemplateParams)
                parameters[parameter.Key] = parameter.Value;
        }
        var body = template.Body;
        if (template.AllowedMinutes is { } allowedMinutes)
        {
            if (parameters.Count != 1 || !parameters.TryGetValue("minutes", out var rawMinutes) ||
                !int.TryParse(rawMinutes, NumberStyles.None, CultureInfo.InvariantCulture,
                    out var minutes) || !allowedMinutes.Contains(minutes))
                return BookingChatErrors.InvalidRequest("Số phút dự kiến phải là 5, 10, 15 hoặc 20.");
            body = body.Replace("{minutes}", minutes.ToString(CultureInfo.InvariantCulture),
                StringComparison.Ordinal);
        }
        else if (parameters.Count != 0)
        {
            return BookingChatErrors.InvalidRequest("Mẫu tin nhắn không nhận tham số.");
        }
        return new PreparedMessage("quick_message", body, template.Key, template.Version,
            JsonSerializer.Serialize(parameters));
    }

    public static IReadOnlyList<BookingChatTemplateResponse> GetTemplates(
        string role, BookingStatus status)
    {
        if (status is BookingStatus.CheckoutPendingReview or BookingStatus.Completed)
            return
            [
                new("common.thanks", 1, "Cảm ơn bạn."),
                new("common.items_received", 1, "Tôi đã nhận đủ đồ dùng.")
            ];
        if (role == "CAREGIVER")
        {
            if (status == BookingStatus.CaregiverAccepted)
                return
                [
                    new("caregiver.accepted_on_time", 1, "Tôi đã nhận lịch và sẽ đến đúng giờ."),
                    new("caregiver.confirm_address", 1, "Bạn xác nhận giúp tôi địa chỉ nhé.")
                ];
            if (status == BookingStatus.CaregiverEnRoute)
                return
                [
                    new("caregiver.en_route", 1, "Tôi đang trên đường đến."),
                    new("caregiver.arrival_eta", 1,
                        "Tôi sắp tới, dự kiến khoảng {minutes} phút nữa.", [5, 10, 15, 20]),
                    new("caregiver.waiting", 1, "Tôi đang đợi tại điểm hẹn."),
                    new("caregiver.pickup_help", 1, "Tôi cần bạn hướng dẫn thêm về điểm đón.")
                ];
            if (status == BookingStatus.InProgress)
                return [new("caregiver.arrived", 1, "Tôi đã đến nơi.")];
        }
        else
        {
            if (status == BookingStatus.CaregiverAccepted)
                return
                [
                    new("customer.use_booking_address", 1, "Bạn cứ đến theo địa chỉ trong lịch nhé."),
                    new("customer.call_on_arrival", 1, "Vui lòng gọi khi bạn đến."),
                    new("customer.meet_at_address", 1, "Tôi sẽ ra đón.")
                ];
            if (status == BookingStatus.CaregiverEnRoute)
                return
                [
                    new("customer.acknowledged", 1, "Tôi đã nhận được thông báo."),
                    new("customer.need_more_time", 1, "Tôi cần thêm ít phút.")
                ];
        }
        return [];
    }

    public static string ComputePayloadHash(PreparedMessage message, Guid expectedEpochId)
    {
        var canonical = string.Join('\n', message.Kind, message.Body,
            message.TemplateKey ?? string.Empty,
            message.TemplateVersion?.ToString(CultureInfo.InvariantCulture) ?? string.Empty,
            message.TemplateParamsJson ?? string.Empty, expectedEpochId.ToString("N"));
        return Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(canonical)))
            .ToLowerInvariant();
    }

    internal sealed record PreparedMessage(
        string Kind,
        string Body,
        string? TemplateKey,
        int? TemplateVersion,
        string? TemplateParamsJson);
}
