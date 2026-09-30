using CareSitter.SharedKernel.Domain;
using CareSitter.SharedKernel.Results;

namespace CareSitter.Modules.Promotion.Domain;

public enum PromotionDiscountType
{
    Percentage,
    FixedAmount
}

public sealed class Promotion : AggregateRoot
{
    private readonly List<PromotionServiceScope> _serviceScopes = [];

    private Promotion() { }

    private Promotion(Guid id) : base(id) { }

    public string Code { get; private set; } = null!;
    public string Title { get; private set; } = null!;
    public string Summary { get; private set; } = null!;
    public string? Description { get; private set; }
    public string BadgeText { get; private set; } = null!;
    public string TermsJson { get; private set; } = "[]";
    public PromotionDiscountType DiscountType { get; private set; }
    public long DiscountValue { get; private set; }
    public long? MaxDiscountAmount { get; private set; }
    public long MinOrderAmount { get; private set; }
    public DateTimeOffset StartsAt { get; private set; }
    public DateTimeOffset EndsAt { get; private set; }
    public bool IsActive { get; private set; }
    public bool FirstPaidBookingOnly { get; private set; }
    public int? TotalUsageLimit { get; private set; }
    public int PerCustomerUsageLimit { get; private set; }
    public int Priority { get; private set; }
    public bool IsFeatured { get; private set; }

    public IReadOnlyCollection<PromotionServiceScope> ServiceScopes => _serviceScopes;

    public static Result<Promotion> Create(string code, string title, string summary,
        string badgeText, PromotionDiscountType discountType, long discountValue,
        long minOrderAmount, DateTimeOffset startsAt, DateTimeOffset endsAt,
        long? maxDiscountAmount = null)
    {
        if (string.IsNullOrWhiteSpace(code) || string.IsNullOrWhiteSpace(title) ||
            string.IsNullOrWhiteSpace(summary) || string.IsNullOrWhiteSpace(badgeText) ||
            discountValue <= 0 || minOrderAmount < 0 || endsAt <= startsAt ||
            (discountType == PromotionDiscountType.Percentage && discountValue > 100) ||
            maxDiscountAmount is <= 0)
            return PromotionErrors.InvalidDiscountConfiguration();

        return new Promotion(Guid.NewGuid())
        {
            Code = code.Trim().ToUpperInvariant(),
            Title = title.Trim(),
            Summary = summary.Trim(),
            BadgeText = badgeText.Trim(),
            DiscountType = discountType,
            DiscountValue = discountValue,
            MaxDiscountAmount = maxDiscountAmount,
            MinOrderAmount = minOrderAmount,
            StartsAt = startsAt,
            EndsAt = endsAt,
            IsActive = true,
            PerCustomerUsageLimit = 1
        };
    }

    public bool IsAvailableAt(DateTimeOffset now) =>
        IsActive && StartsAt <= now && EndsAt >= now;

    public bool AppliesToService(Guid serviceTypeId) =>
        _serviceScopes.Count == 0 || _serviceScopes.Any(x => x.ServiceTypeId == serviceTypeId);

    public Result<long> CalculateDiscount(long grossAmount)
    {
        if (grossAmount <= 0)
            return PromotionErrors.InvalidGrossAmount();
        if (grossAmount < MinOrderAmount)
            return PromotionErrors.MinimumOrderNotMet(MinOrderAmount);

        long discount;
        try
        {
            discount = DiscountType switch
            {
                PromotionDiscountType.Percentage => checked(grossAmount * DiscountValue / 100),
                PromotionDiscountType.FixedAmount => DiscountValue,
                _ => 0
            };
        }
        catch (OverflowException)
        {
            return PromotionErrors.InvalidDiscountConfiguration();
        }

        if (MaxDiscountAmount is { } cap)
            discount = Math.Min(discount, cap);

        // The current payment flow always creates a provider intent, so a fully-free
        // booking is deliberately rejected until a zero-payment confirmation path exists.
        if (discount >= grossAmount)
            return PromotionErrors.ZeroPaymentNotSupported();
        discount = Math.Max(discount, 0);
        return discount > 0
            ? discount
            : PromotionErrors.InvalidDiscountConfiguration();
    }
}

public sealed class PromotionServiceScope
{
    private PromotionServiceScope() { }

    public Guid PromotionId { get; private set; }
    public Guid ServiceTypeId { get; private set; }
}
