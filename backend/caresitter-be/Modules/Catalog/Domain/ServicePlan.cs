using CareSitter.SharedKernel.Domain;
using CareSitter.SharedKernel.Results;

namespace CareSitter.Modules.Catalog.Domain;

public static class ServicePlanBillingUnits
{
    public const string Session = "SESSION";
    public const string SessionPackage = "SESSION_PACKAGE";

    public static bool IsSupported(string value) =>
        value is Session or SessionPackage;
}

/// <summary>
/// Phương án mua của một dịch vụ. Tách khỏi PricingRule vì giá theo buổi/gói
/// không được nhân với số giờ như bảng giá booking cũ.
/// </summary>
public sealed class ServicePlan : Entity
{
    private ServicePlan() { }

    private ServicePlan(Guid id, Guid serviceTypeId) : base(id)
    {
        ServiceTypeId = serviceTypeId;
    }

    public Guid ServiceTypeId { get; private set; }
    public string Code { get; private set; } = null!;
    public string Name { get; private set; } = null!;
    public string? Description { get; private set; }
    public string BillingUnit { get; private set; } = null!;
    public int DurationMinutes { get; private set; }
    public int IncludedSessions { get; private set; }
    public long TotalPrice { get; private set; }
    public int? ValidityDays { get; private set; }
    public decimal PlatformFeePercent { get; private set; }
    public int DisputeWindowHours { get; private set; }
    public int SortOrder { get; private set; }
    public DateTimeOffset EffectiveFrom { get; private set; }
    public DateTimeOffset? EffectiveTo { get; private set; }
    public bool IsActive { get; private set; }

    public static Result<ServicePlan> Create(
        Guid serviceTypeId,
        string code,
        string name,
        string billingUnit,
        int durationMinutes,
        int includedSessions,
        long totalPrice,
        string? description = null,
        int? validityDays = null,
        decimal platformFeePercent = 15m,
        int disputeWindowHours = 48,
        int sortOrder = 0,
        DateTimeOffset? effectiveFrom = null,
        DateTimeOffset? effectiveTo = null,
        bool isActive = true)
    {
        if (serviceTypeId == Guid.Empty)
            return Error.Validation("service_plan.service_type_id", "Dịch vụ là bắt buộc.");
        if (string.IsNullOrWhiteSpace(code) || code.Trim().Length > 100)
            return Error.Validation("service_plan.code", "Mã phương án là bắt buộc và tối đa 100 ký tự.");
        if (string.IsNullOrWhiteSpace(name) || name.Trim().Length > 255)
            return Error.Validation("service_plan.name", "Tên phương án là bắt buộc và tối đa 255 ký tự.");

        var normalizedUnit = billingUnit.Trim().ToUpperInvariant();
        if (!ServicePlanBillingUnits.IsSupported(normalizedUnit))
            return Error.Validation("service_plan.billing_unit", "Đơn vị giá phải là SESSION hoặc SESSION_PACKAGE.");
        if (durationMinutes is < 15 or > 1440)
            return Error.Validation("service_plan.duration_minutes", "Thời lượng một buổi phải từ 15 đến 1.440 phút.");
        if (includedSessions < 1)
            return Error.Validation("service_plan.included_sessions", "Số buổi phải lớn hơn 0.");
        if (normalizedUnit == ServicePlanBillingUnits.Session && includedSessions != 1)
            return Error.Validation("service_plan.included_sessions", "Phương án theo buổi chỉ được chứa một buổi.");
        if (normalizedUnit == ServicePlanBillingUnits.SessionPackage && includedSessions < 2)
            return Error.Validation("service_plan.included_sessions", "Gói nhiều buổi phải có ít nhất hai buổi.");
        if (totalPrice < 0)
            return Error.Validation("service_plan.total_price", "Giá gói không được âm.");
        if (validityDays is <= 0 or > 3650)
            return Error.Validation("service_plan.validity_days", "Hạn sử dụng phải từ 1 đến 3.650 ngày.");
        if (normalizedUnit == ServicePlanBillingUnits.SessionPackage && validityDays is null)
            return Error.Validation("service_plan.validity_days", "Gói nhiều buổi phải có hạn sử dụng.");
        if (platformFeePercent is < 0 or > 100)
            return Error.Validation("service_plan.platform_fee_percent", "Phí nền tảng phải nằm trong khoảng 0 đến 100%.");
        if (disputeWindowHours is < 1 or > 720)
            return Error.Validation("service_plan.dispute_window_hours", "Thời hạn khiếu nại phải từ 1 đến 720 giờ.");

        var from = effectiveFrom ?? DateTimeOffset.UtcNow;
        if (effectiveTo.HasValue && effectiveTo <= from)
            return Error.Validation("service_plan.effective_to", "Thời điểm kết thúc phải sau thời điểm bắt đầu.");

        return new ServicePlan(Guid.NewGuid(), serviceTypeId)
        {
            Code = code.Trim().ToUpperInvariant(),
            Name = name.Trim(),
            Description = string.IsNullOrWhiteSpace(description) ? null : description.Trim(),
            BillingUnit = normalizedUnit,
            DurationMinutes = durationMinutes,
            IncludedSessions = includedSessions,
            TotalPrice = totalPrice,
            ValidityDays = validityDays,
            PlatformFeePercent = platformFeePercent,
            DisputeWindowHours = disputeWindowHours,
            SortOrder = sortOrder,
            EffectiveFrom = from,
            EffectiveTo = effectiveTo,
            IsActive = isActive
        };
    }
}
