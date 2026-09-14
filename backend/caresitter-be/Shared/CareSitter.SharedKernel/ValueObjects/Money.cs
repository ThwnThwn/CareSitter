namespace CareSitter.SharedKernel.ValueObjects;

/// <summary>
/// Tien VND luu bang so nguyen (dong). Khong dung float/decimal cho luong tien noi bo.
/// </summary>
public readonly record struct Money(long Amount, string Currency = "VND")
{
    public static Money Vnd(long amount) => new(amount);

    public static Money operator +(Money a, Money b)
    {
        EnsureSameCurrency(a, b);
        return a with { Amount = a.Amount + b.Amount };
    }

    public static Money operator -(Money a, Money b)
    {
        EnsureSameCurrency(a, b);
        return a with { Amount = a.Amount - b.Amount };
    }

    public bool IsNegative => Amount < 0;

    private static void EnsureSameCurrency(Money a, Money b)
    {
        if (a.Currency != b.Currency)
            throw new InvalidOperationException($"không thể cong tru tien khac don vi: {a.Currency} vs {b.Currency}.");
    }

    public override string ToString() => $"{Amount} {Currency}";
}
