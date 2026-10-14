using System.Text.RegularExpressions;
using CareSitter.SharedKernel.Results;

namespace CareSitter.Modules.Support.Domain;

/// <summary>A request for a callback, not a booking or a quoted price.</summary>
public sealed class ConsultationRequest
{
    private ConsultationRequest() { }
    public Guid Id { get; private set; }
    public string ContactName { get; private set; } = "";
    public string Phone { get; private set; } = "";
    public string ServiceCategory { get; private set; } = "";
    public DateOnly PreferredDate { get; private set; }
    public int Hours { get; private set; }
    public string? CaregiverPreference { get; private set; }
    public string? Note { get; private set; }
    public DateTime ConsentAt { get; private set; }
    public DateTime CreatedAt { get; private set; }
    public string PayloadHash { get; private set; } = "";

    public static Result<ConsultationRequest> Create(Guid id, string? contactName,
        string? phone, string? serviceCategory, DateOnly preferredDate, int hours,
        string? caregiverPreference, string? note, bool consent, DateTime utcNow)
    {
        var name = contactName?.Trim() ?? "";
        var normalizedPhone = Regex.Replace(phone ?? "", @"[\s().-]", "");
        if (normalizedPhone.StartsWith("+84", StringComparison.Ordinal))
            normalizedPhone = "0" + normalizedPhone[3..];
        if (id == Guid.Empty)
            return Error.Validation("consultation.key", "Thiếu mã yêu cầu hợp lệ.");
        if (name.Length is < 2 or > 120)
            return Error.Validation("consultation.name", "Họ tên cần từ 2 đến 120 ký tự.");
        if (!Regex.IsMatch(normalizedPhone, @"^0[35789][0-9]{8}$"))
            return Error.Validation("consultation.phone", "Vui lòng nhập số điện thoại Việt Nam hợp lệ.");
        if (serviceCategory is not ("elderly_care" or "daily_companionship" or "mobility_support"))
            return Error.Validation("consultation.service", "Loại hỗ trợ không hợp lệ.");
        if (preferredDate == default)
            return Error.Validation("consultation.date", "Cần chọn ngày dự kiến hợp lệ.");
        if (hours is not (2 or 4 or 8 or 12))
            return Error.Validation("consultation.hours", "Thời lượng không hợp lệ.");
        if (caregiverPreference?.Trim().Length > 120 || note?.Trim().Length > 1000)
            return Error.Validation("consultation.note", "Nội dung yêu cầu vượt quá độ dài cho phép.");
        if (!consent)
            return Error.Validation("consultation.consent", "Cần đồng ý để CareSitter liên hệ tư vấn.");
        return new ConsultationRequest
        {
            Id = id, ContactName = name, Phone = normalizedPhone,
            ServiceCategory = serviceCategory, PreferredDate = preferredDate,
            Hours = hours, CaregiverPreference = EmptyToNull(caregiverPreference),
            Note = EmptyToNull(note), ConsentAt = utcNow, CreatedAt = utcNow
        };
    }

    // Apply only to a new submission. A saved request remains replayable after midnight.
    public Result ValidateNewSubmission() =>
        PreferredDate < DateOnly.FromDateTime(CreatedAt.AddHours(7))
            ? Error.Validation("consultation.date", "Ngày bắt đầu không được trong quá khứ.")
            : Result.Success();

    private static string? EmptyToNull(string? value) =>
        string.IsNullOrWhiteSpace(value) ? null : value.Trim();
}
