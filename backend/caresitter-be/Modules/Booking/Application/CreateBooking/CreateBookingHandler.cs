using CareSitter.Contracts.Services;
using CareSitter.Infrastructure.Security;
using CareSitter.Infrastructure.Time;
using CareSitter.Modules.Booking.Domain;
using CareSitter.Modules.Booking.Infrastructure;
using CareSitter.SharedKernel.Results;
using MediatR;
using Microsoft.EntityFrameworkCore;
using System.Text.Json;

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
        if (!await catalog.AddressIsVerifiedForBookingAsync(request.AddressId, customerId, ct))
            return Error.Validation("booking.address_unverified",
                "Vui long chon dia chi tu danh sach goi y truoc khi dat lich.");
        if (!await catalog.ServiceIsActiveAsync(request.ServiceTypeId, ct))
            return Error.Validation("booking.service", "Dich vu khong hoat dong.");
        if (request.CaregiverId is not null)
            return Error.Validation("booking.caregiver_selection_flow",
                "Vui long tao booking truoc, sau do chon caregiver qua PUT /api/v1/bookings/{id}/caregiver.");

        var created = Domain.Booking.Create(customerId, request.BeneficiaryId, request.AddressId,
            request.ServiceTypeId, request.ScheduledStart, request.ScheduledEnd,
            requiredSkills: request.RequiredSkills is { Count: > 0 }
                ? JsonSerializer.Serialize(request.RequiredSkills)
                : null);
        if (created.IsFailure) return created.Error;

        var quote = await pricing.QuoteAsync(request.ServiceTypeId,
            request.ScheduledStart, request.ScheduledEnd, ct);
        if (quote.IsFailure) return quote.Error;
        var booking = created.Value;
        booking.ApplyPricing(quote.Value.EscrowAmount, quote.Value.PlatformFeeAmount,
            quote.Value.CaregiverEarningAmount, quote.Value.PriceSnapshotJson);
        booking.TransitionTo(BookingStatus.PendingPayment);

        db.Bookings.Add(booking);
        await db.SaveChangesAsync(ct);
        return booking.Id;
    }
}
