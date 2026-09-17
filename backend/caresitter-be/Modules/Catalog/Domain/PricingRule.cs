using CareSitter.SharedKernel.Domain;
using CareSitter.SharedKernel.Results;

namespace CareSitter.Modules.Catalog.Domain;

/// <summary>
/// Quy tac tinh gia gan voi 1 service_type. Map sang bang pricing_rules. Bang KHONG co
/// created_at/updated_at -> Ignore ca CreatedAt lan UpdatedAt. effective_from la field
/// domain (hieu luc tu), khong phai Entity.CreatedAt.
/// </summary>
public sealed class PricingRule : Entity
{
    private PricingRule() { } // EF

    private PricingRule(
        Guid id,
        string name,
        Guid serviceTypeId,
        long baseHourlyPrice,
        decimal nightMultiplier,
        decimal holidayMultiplier,
        decimal platformFeePercent,
        int disputeWindowHours,
        string? holidays,
        string? cancellationPolicy,
        DateTimeOffset effectiveFrom,
        DateTimeOffset? effectiveTo,
        bool isActive,
        Guid? createdByAdminId) : base(id)
    {
        Name = name;
        ServiceTypeId = serviceTypeId;
        BaseHourlyPrice = baseHourlyPrice;
        NightMultiplier = nightMultiplier;
        HolidayMultiplier = holidayMultiplier;
        PlatformFeePercent = platformFeePercent;
        DisputeWindowHours = disputeWindowHours;
        Holidays = holidays;
        CancellationPolicy = cancellationPolicy;
        EffectiveFrom = effectiveFrom;
        EffectiveTo = effectiveTo;
        IsActive = isActive;
        CreatedByAdminId = createdByAdminId;
    }

    public string Name { get; private set; } = null!;
    public Guid ServiceTypeId { get; private set; }
    public long BaseHourlyPrice { get; private set; }
    public decimal NightMultiplier { get; private set; }
    public decimal HolidayMultiplier { get; private set; }
    public decimal PlatformFeePercent { get; private set; }
    public int DisputeWindowHours { get; private set; }

    /// <summary>jsonb — [{date, multiplier}].</summary>
    public string? Holidays { get; private set; }

    /// <summary>jsonb — cancellation_policies.</summary>
    public string? CancellationPolicy { get; private set; }
    public DateTimeOffset EffectiveFrom { get; private set; }
    public DateTimeOffset? EffectiveTo { get; private set; }
    public bool IsActive { get; private set; }
    public Guid? CreatedByAdminId { get; private set; }

    public Result Update(
        string name,
        long baseHourlyPrice,
        decimal nightMultiplier,
        decimal holidayMultiplier,
        decimal platformFeePercent,
        int disputeWindowHours,
        DateTimeOffset effectiveFrom,
        DateTimeOffset? effectiveTo)
    {
        if (string.IsNullOrWhiteSpace(name))
            return Error.Validation("pricing_rule.name", "Tên bảng giá là bắt buộc.");
        if (baseHourlyPrice < 0)
            return Error.Validation("pricing_rule.base_hourly_price", "Giá theo giờ không được âm.");
        if (nightMultiplier is < 1 or > 10 || holidayMultiplier is < 1 or > 10)
            return Error.Validation("pricing_rule.multiplier", "Hệ số phải nằm trong khoảng 1 đến 10.");
        if (platformFeePercent is < 0 or > 100)
            return Error.Validation("pricing_rule.platform_fee_percent", "Phí nền tảng phải nằm trong khoảng 0 đến 100%.");
        if (disputeWindowHours is < 1 or > 720)
            return Error.Validation("pricing_rule.dispute_window_hours", "Thời hạn khiếu nại phải từ 1 đến 720 giờ.");
        if (effectiveTo.HasValue && effectiveTo <= effectiveFrom)
            return Error.Validation("pricing_rule.effective_to", "Thời điểm kết thúc phải sau thời điểm bắt đầu.");

        Name = name.Trim();
        BaseHourlyPrice = baseHourlyPrice;
        NightMultiplier = nightMultiplier;
        HolidayMultiplier = holidayMultiplier;
        PlatformFeePercent = platformFeePercent;
        DisputeWindowHours = disputeWindowHours;
        EffectiveFrom = effectiveFrom;
        EffectiveTo = effectiveTo;
        return Result.Success();
    }

    public void SetActive(bool isActive) => IsActive = isActive;

    public static Result<PricingRule> Create(
        string name,
        Guid serviceTypeId,
        long baseHourlyPrice,
        decimal nightMultiplier = 1.00m,
        decimal holidayMultiplier = 1.00m,
        decimal platformFeePercent = 15.00m,
        int disputeWindowHours = 48,
        string? holidays = null,
        string? cancellationPolicy = null,
        DateTimeOffset? effectiveFrom = null,
        DateTimeOffset? effectiveTo = null,
        bool isActive = true,
        Guid? createdByAdminId = null)
    {
        if (string.IsNullOrWhiteSpace(name))
            return Error.Validation("pricing_rule.name", "name la bat buoc.");
        if (serviceTypeId == Guid.Empty)
            return Error.Validation("pricing_rule.service_type_id", "service_type_id la bat buoc.");
        if (baseHourlyPrice < 0)
            return Error.Validation("pricing_rule.base_hourly_price", "base_hourly_price không được am.");

        return new PricingRule(Guid.NewGuid(), name, serviceTypeId, baseHourlyPrice,
            nightMultiplier, holidayMultiplier, platformFeePercent, disputeWindowHours,
            holidays, cancellationPolicy, effectiveFrom ?? DateTimeOffset.UtcNow, effectiveTo,
            isActive, createdByAdminId);
    }
}
