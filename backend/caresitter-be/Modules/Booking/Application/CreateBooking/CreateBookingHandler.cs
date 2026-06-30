using CareSitter.Contracts.Services;
using CareSitter.Modules.Booking.Infrastructure;
using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Booking.Application.CreateBooking;

internal sealed class CreateBookingHandler : IRequestHandler<CreateBookingCommand, Result<Guid>>
{
    private readonly BookingDbContext _db;
    private readonly IPricingService _pricing;

    public CreateBookingHandler(BookingDbContext db, IPricingService pricing)
    {
        _db = db;
        _pricing = pricing;
    }

    public async Task<Result<Guid>> Handle(CreateBookingCommand request, CancellationToken ct)
    {
        var create = Domain.Booking.Create(
            request.CustomerId,
            request.BeneficiaryId,
            request.AddressId,
            request.ServiceTypeId,
            request.ScheduledStart,
            request.ScheduledEnd);

        if (create.IsFailure)
            return Result.Failure<Guid>(create.Error);

        var booking = create.Value;

        // Lay bao gia tu Catalog (cross-module qua interface, khong query DbContext cheo).
        var quote = await _pricing.QuoteAsync(request.ServiceTypeId, request.ScheduledStart, request.ScheduledEnd, ct);
        if (quote.IsSuccess)
            booking.ApplyPricing(quote.Value.EscrowAmount, quote.Value.PlatformFeeAmount,
                quote.Value.CaregiverEarningAmount);

        _db.Bookings.Add(booking);
        await _db.SaveChangesAsync(ct);

        return booking.Id;
    }
}
