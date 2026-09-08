using CareSitter.Contracts.Services;
using CareSitter.Infrastructure.Security;
using CareSitter.Infrastructure.Time;
using CareSitter.Modules.Booking.Domain;
using CareSitter.Modules.Booking.Infrastructure;
using CareSitter.SharedKernel.Results;
using MediatR;
using Microsoft.EntityFrameworkCore;

namespace CareSitter.Modules.Booking.Application.CreateBooking;

internal sealed class CreateBookingHandler(
    BookingDbContext db,
    IPricingService pricing,
    IPeopleLookupService people,
    ICatalogLookupService catalog,
    ICurrentUser currentUser,
    IClock clock) : IRequestHandler<CreateBookingCommand, Result<Guid>>
{
    public async Task<Result<Guid>> Handle(CreateBookingCommand request, CancellationToken ct)
    {
        if (currentUser.UserId is not { } customerId)
            return Error.Forbidden("booking.unauthenticated", "Khong xac dinh duoc nguoi dung.");
        if (request.ScheduledStart <= clock.UtcNow || request.ScheduledEnd <= request.ScheduledStart)
            return Error.Validation("booking.schedule", "Lich cham soc phai nam trong tuong lai.");
        if (!await people.BeneficiaryBelongsToAsync(request.BeneficiaryId, customerId, ct))
            return Error.Validation("booking.beneficiary", "Nguoi duoc cham soc khong hop le.");
        if (!await catalog.AddressBelongsToAsync(request.AddressId, customerId, ct))
            return Error.Validation("booking.address", "Dia chi khong hop le.");
        if (!await catalog.ServiceIsActiveAsync(request.ServiceTypeId, ct))
            return Error.Validation("booking.service", "Dich vu khong hoat dong.");
        if (request.CaregiverId is { } caregiverId &&
            !await people.CaregiverIsAvailableAsync(caregiverId, request.ScheduledStart, request.ScheduledEnd, ct))
            return Error.Conflict("booking.caregiver_unavailable", "Caregiver khong ranh trong khung gio nay.");

        // Kiểm tra double-booking: caregiver đã có ca active trùng khung giờ chưa?
        if (request.CaregiverId is { } cgId)
        {
            var hasConflict = await db.Bookings.AsNoTracking().AnyAsync(x =>
                x.CaregiverId == cgId &&
                x.Status != BookingStatus.Completed &&
                x.Status != BookingStatus.Cancelled &&
                x.ScheduledStart < request.ScheduledEnd &&
                x.ScheduledEnd > request.ScheduledStart, ct);
            if (hasConflict)
                return Error.Conflict("booking.caregiver_double_booked",
                    "Caregiver da co ca cham soc trong khung gio nay.");
        }

        var created = Domain.Booking.Create(customerId, request.BeneficiaryId, request.AddressId,
            request.ServiceTypeId, request.ScheduledStart, request.ScheduledEnd);
        if (created.IsFailure) return created.Error;

        var quote = await pricing.QuoteAsync(request.ServiceTypeId,
            request.ScheduledStart, request.ScheduledEnd, ct);
        if (quote.IsFailure) return quote.Error;
        var booking = created.Value;
        booking.ApplyPricing(quote.Value.EscrowAmount, quote.Value.PlatformFeeAmount,
            quote.Value.CaregiverEarningAmount, quote.Value.PriceSnapshotJson);
        if (request.CaregiverId is { } selectedCaregiver)
            booking.SelectCaregiver(selectedCaregiver);
        booking.TransitionTo(BookingStatus.PendingPayment);

        db.Bookings.Add(booking);
        await db.SaveChangesAsync(ct);
        return booking.Id;
    }
}
