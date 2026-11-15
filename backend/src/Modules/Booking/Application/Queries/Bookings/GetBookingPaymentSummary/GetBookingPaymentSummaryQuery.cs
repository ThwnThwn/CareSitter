using CareSitter.Contracts.Services;
using CareSitter.Modules.Booking.Application.Commands;
using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Booking.Application;

public sealed record GetBookingPaymentSummaryQuery(Guid BookingId)
    : IRequest<Result<BookingPaymentSummaryResponse>>;

internal sealed class GetBookingPaymentSummaryQueryHandler(
    IBookingReadStore store, ICurrentUser user, IClock clock)
    : IRequestHandler<GetBookingPaymentSummaryQuery, Result<BookingPaymentSummaryResponse>>
{
    public async Task<Result<BookingPaymentSummaryResponse>> Handle(
        GetBookingPaymentSummaryQuery request, CancellationToken ct)
    {
        if (user.UserId is not { } userId) return BookingErrors.Unauthenticated();
        var booking = await store.GetAsync(request.BookingId, ct);
        if (booking is null) return BookingErrors.NotFound();
        if (booking.CustomerId != userId) return BookingErrors.Forbidden();
        return BookingPaymentSummaryPolicy.Describe(booking, clock.UtcNow);
    }
}
