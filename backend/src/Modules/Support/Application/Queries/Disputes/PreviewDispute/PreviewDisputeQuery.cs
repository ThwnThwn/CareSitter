using CareSitter.Contracts.Services;
using CareSitter.Modules.Support.Domain;
using CareSitter.Modules.Support.Application.Commands;
using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Support.Application;

public sealed record PreviewDisputeQuery(Guid Id, string Decision, long? Refund, long? Penalty) : IRequest<Result<DisputeQuote>>;

internal sealed class PreviewDisputeQueryHandler(ISupportRepository disputes, IDisputeBookingWorkflow bookings,
    ICurrentUser user, IDisputePricing pricing) : IRequestHandler<PreviewDisputeQuery, Result<DisputeQuote>>
{
    public async Task<Result<DisputeQuote>> Handle(PreviewDisputeQuery request, CancellationToken ct)
    {
        if (!user.IsInRole("ADMIN")) return SupportErrors.Forbidden();
        var dispute = await disputes.GetDisputeAsync(request.Id, ct);
        if (dispute is null) return SupportErrors.NotFound();
        var booking = await bookings.GetAsync(dispute.BookingId, ct);
        if (booking is null) return SupportErrors.DisputeBookingNotFound();
        if (booking.Status != "disputed" || dispute.Status is not ("OPEN" or "INVESTIGATING"))
            return SupportErrors.DisputeInvalidState();
        return pricing.Quote(booking, request.Decision, request.Refund, request.Penalty);
    }
}
