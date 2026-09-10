namespace CareSitter.Contracts.Services;

/// <summary>Support module exposes dispute state without leaking its DbContext across modules.</summary>
public interface IDisputeLookupService
{
    Task<bool> HasOpenDisputeAsync(Guid bookingId, CancellationToken ct = default);
}
