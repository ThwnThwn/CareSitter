namespace CareSitter.Infrastructure.Time;

/// <summary>Bao boc thoi gian de test deterministic.</summary>
public interface IClock
{
    DateTimeOffset UtcNow { get; }
}

public sealed class SystemClock : IClock
{
    public DateTimeOffset UtcNow => DateTimeOffset.UtcNow;
}
