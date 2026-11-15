using CareSitter.Contracts.Services;

namespace CareSitter.Modules.Booking.Application;

internal interface IBookingMatchingPreview
{
    Task<IReadOnlyList<MatchingCandidate>> PreviewAsync(Domain.Booking booking, CancellationToken ct);
}
