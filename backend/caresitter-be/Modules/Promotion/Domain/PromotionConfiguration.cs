using System.Text.RegularExpressions;
using CareSitter.SharedKernel.Results;

namespace CareSitter.Modules.Promotion.Domain;

public sealed record PromotionConfiguration(
    string Code, string Title, string Summary, string? Description, string BadgeText,
    IReadOnlyList<string> Terms, PromotionDiscountType DiscountType, long DiscountValue,
    long? MaxDiscountAmount, long MinOrderAmount, DateTimeOffset StartsAt, DateTimeOffset EndsAt,
    bool IsActive, bool FirstPaidBookingOnly, int? TotalUsageLimit, int PerCustomerUsageLimit,
    int Priority, bool IsFeatured, IReadOnlyList<Guid> EligibleServiceIds)
{
    public const long MaxMoney = 9_007_199_254_740_991;

    public Result Validate()
    {
        if (Code is null || !Regex.IsMatch(Code.Trim(), "^[A-Za-z0-9_-]{1,50}$"))
            return Invalid("Mã ưu đãi gồm 1–50 chữ cái, chữ số, dấu gạch ngang hoặc gạch dưới.");
        if (string.IsNullOrWhiteSpace(Title) || Title.Trim().Length > 160 ||
            string.IsNullOrWhiteSpace(Summary) || Summary.Trim().Length > 300 ||
            string.IsNullOrWhiteSpace(BadgeText) || BadgeText.Trim().Length > 50 ||
            Description?.Length > 10_000)
            return Invalid("Tên, tóm tắt, nhãn ưu đãi hoặc mô tả không hợp lệ.");
        if (!Enum.IsDefined(DiscountType) || DiscountValue <= 0 || DiscountValue > MaxMoney ||
            (DiscountType == PromotionDiscountType.Percentage && DiscountValue > 100) ||
            MaxDiscountAmount is <= 0 or > MaxMoney || MinOrderAmount < 0 || MinOrderAmount > MaxMoney)
            return Invalid("Giá trị giảm phải dương; phần trăm tối đa 100%; số tiền phải là số nguyên VND hợp lệ.");
        if (StartsAt == default || EndsAt == default || EndsAt <= StartsAt)
            return Invalid("Thời điểm kết thúc phải sau thời điểm bắt đầu.");
        if (TotalUsageLimit is <= 0 || PerCustomerUsageLimit <= 0 || Priority < 0)
            return Invalid("Giới hạn lượt phải lớn hơn 0; độ ưu tiên không được âm.");
        if (Terms is null || Terms.Count > 20 || Terms.Any(x => string.IsNullOrWhiteSpace(x) || x.Length > 500))
            return Invalid("Tối đa 20 điều kiện, mỗi điều kiện từ 1 đến 500 ký tự.");
        if (EligibleServiceIds is null || EligibleServiceIds.Count > 100 ||
            EligibleServiceIds.Any(x => x == Guid.Empty) ||
            EligibleServiceIds.Distinct().Count() != EligibleServiceIds.Count)
            return Invalid("Danh sách dịch vụ không hợp lệ hoặc bị trùng (tối đa 100 dịch vụ).");
        return Result.Success();
    }

    private static Error Invalid(string message) => Error.Validation("promotion.invalid_configuration", message);
}
