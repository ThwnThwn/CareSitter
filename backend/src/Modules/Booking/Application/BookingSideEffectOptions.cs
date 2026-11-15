namespace CareSitter.Modules.Booking.Application;

internal sealed class BookingSideEffectOptions
{
    public const string SectionName = "BookingSideEffects";

    public int PollIntervalSeconds { get; init; } = 1;
    public int LeaseSeconds { get; init; } = 30;
    public int BatchSize { get; init; } = 50;
    public int MaxAttempts { get; init; } = 10;
    public int RetryDelaySeconds { get; init; } = 5;
}
