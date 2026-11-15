namespace CareSitter.Messaging.Kafka.Failures;

/// <summary>Bounded retry delay with jitter for transient consumer failures.</summary>
public sealed class ConsumerRetryPolicy
{
    /// <summary>Returns a delay bounded by 16 seconds plus at most 250 milliseconds of jitter.</summary>
    public TimeSpan Delay(int retry) => TimeSpan.FromMilliseconds(
        Math.Min(16000, 1000 * (1 << Math.Clamp(retry, 0, 8))) + Random.Shared.Next(0, 251));
}
