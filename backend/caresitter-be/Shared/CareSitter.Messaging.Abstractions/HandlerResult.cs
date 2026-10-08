namespace CareSitter.Messaging.Abstractions;

/// <summary>The handler outcome used to decide retry, acknowledgement or quarantine.</summary>
public enum HandlerOutcome { Success, Transient, Permanent }

/// <summary>Determines whether a consumer continues after a poison message is quarantined.</summary>
public enum PoisonPolicy { Skip, Halt }

/// <summary>A bounded failure description. Payloads and credentials must not appear in Reason.</summary>
public sealed record HandlerResult(HandlerOutcome Outcome, string? Reason = null)
{
    /// <summary>Indicates that the effect was completed or already completed.</summary>
    public static HandlerResult Success() => new(HandlerOutcome.Success);
    /// <summary>Indicates a recoverable dependency failure.</summary>
    public static HandlerResult Transient(string reason) => new(HandlerOutcome.Transient, reason);
    /// <summary>Indicates an invalid message or a permanent business rejection.</summary>
    public static HandlerResult Permanent(string reason) => new(HandlerOutcome.Permanent, reason);
}
