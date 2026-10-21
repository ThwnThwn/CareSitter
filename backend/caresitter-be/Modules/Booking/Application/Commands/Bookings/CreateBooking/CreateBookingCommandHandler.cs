using CareSitter.Contracts.Services;
using CareSitter.Modules.Booking.Application.Sync;
using CareSitter.Modules.Booking.Domain;
using CareSitter.SharedKernel.Results;
using MediatR;
using Microsoft.Extensions.Options;
using System.Text.Json;

namespace CareSitter.Modules.Booking.Application.Commands.CreateBooking;

internal sealed class CreateBookingCommandHandler(
    IBookingRepository bookings,
    IPricingService pricing,
    IPeopleLookupService people,
    ICatalogLookupService catalog,
    ICurrentUser currentUser,
    IClock clock,
    IPromotionService promotions,
    IOptions<BookingPaymentOptions> paymentOptions,
    IBookingSyncService bookingSync,
    IBookingCreationIdempotencyStore idempotency,
    IBookingResponseMapper responseMapper)
    : IRequestHandler<CreateBookingCommand, Result<BookingResponse>>
{
    public async Task<Result<BookingResponse>> Handle(CreateBookingCommand request, CancellationToken ct)
    {
        if (currentUser.UserId is not { } customerId)
            return Error.Forbidden("booking.unauthenticated", "Khong xac dinh duoc người dùng.");
        if (request.IdempotencyKey == Guid.Empty)
            return Error.Validation("booking.idempotency_key.invalid",
                "Idempotency-Key phải là UUID hợp lệ và khác rỗng.");

        Guid? reservedPromotionBookingId = null;
        Result<Domain.Booking> result;
        try
        {
            result = await idempotency.ExecuteAsync(
                customerId,
                request.IdempotencyKey,
                BookingCreationFingerprint.Compute(request),
                CreateNewBookingAsync,
                ct);
        }
        catch
        {
            if (reservedPromotionBookingId is { } bookingId)
                await promotions.ReleaseAsync(bookingId, customerId,
                    "BOOKING_PERSISTENCE_FAILED", CancellationToken.None);
            throw;
        }
        if (result.IsFailure) return result.Error;
        // The transaction has committed. A later response-mapping failure must not
        // release a promotion already attached to the durable booking.
        reservedPromotionBookingId = null;
        return await responseMapper.ToResponseAsync(result.Value, ct);

        async Task<Result<Domain.Booking>> CreateNewBookingAsync(CancellationToken operationCt)
        {
            if (request.ScheduledStart <= clock.UtcNow || request.ScheduledEnd <= request.ScheduledStart)
                return Error.Validation("booking.schedule", "Lich chăm sóc phai nam trong tuong lai.");
            if (!await people.BeneficiaryBelongsToAsync(request.BeneficiaryId, customerId, operationCt))
                return Error.Validation("booking.beneficiary", "Nguoi duoc chăm sóc khong hop le.");
            if (!await catalog.AddressBelongsToAsync(request.AddressId, customerId, operationCt))
                return Error.Validation("booking.address", "Dia chi khong hop le.");
            if (!await catalog.AddressIsVerifiedForBookingAsync(request.AddressId, customerId, operationCt))
                return Error.Validation("booking.address_unverified",
                    "Vui long chon dia chi tu danh sach goi y truoc khi dat lich.");
            if (!await catalog.ServiceIsActiveAsync(request.ServiceTypeId, operationCt))
                return Error.Validation("booking.service", "Dich vu khong hoat dong.");
            if (await bookings.HasBeneficiaryScheduleConflictAsync(Guid.Empty,
                    request.BeneficiaryId, request.ScheduledStart, request.ScheduledEnd, operationCt))
                return BookingErrors.BeneficiaryScheduleConflict();
            if (request.CaregiverId is not null)
                return Error.Validation("booking.caregiver_selection_flow",
                    "Vui long tao booking truoc, sau do chon caregiver qua PUT /api/v1/bookings/{id}/caregiver.");

            var paymentDeadlineMinutes = Math.Clamp(
                paymentOptions.Value.BookingPaymentDeadlineMinutes, 5, 180);
            var created = Domain.Booking.Create(customerId, request.BeneficiaryId, request.AddressId,
                request.ServiceTypeId, request.ScheduledStart, request.ScheduledEnd,
                paymentDeadline: clock.UtcNow.AddMinutes(paymentDeadlineMinutes),
                requiredSkills: request.RequiredSkills is { Count: > 0 }
                    ? JsonSerializer.Serialize(request.RequiredSkills)
                    : null);
            if (created.IsFailure) return created.Error;

            var quote = await pricing.QuoteAsync(request.ServiceTypeId,
                request.ScheduledStart, request.ScheduledEnd, operationCt);
            if (quote.IsFailure) return quote.Error;
            var booking = created.Value;
            var pricingApplied = booking.ApplyPricing(quote.Value.EscrowAmount,
                quote.Value.PlatformFeeAmount,
                quote.Value.CaregiverEarningAmount, quote.Value.PriceSnapshotJson,
                quote.Value.DisputeWindowHours);
            if (pricingApplied.IsFailure) return pricingApplied.Error;

            var hasPromotion = !string.IsNullOrWhiteSpace(request.PromotionCode);
            if (hasPromotion)
            {
                var reservation = await promotions.ReserveAsync(new PromotionReservationRequest(
                    request.PromotionCode!, customerId, booking.Id, request.ServiceTypeId,
                    request.ScheduledStart, request.ScheduledEnd,
                    booking.PaymentDeadline.AddMinutes(30), quote.Value.EscrowAmount), operationCt);
                if (reservation.IsFailure) return reservation.Error;
                reservedPromotionBookingId = booking.Id;

                var promo = reservation.Value;
                var applied = booking.ApplyPromotion(promo.PromotionId, promo.Code,
                    promo.GrossAmount, promo.DiscountAmount, promo.CustomerPayableAmount,
                    promo.PlatformSubsidyAmount);
                if (applied.IsFailure)
                {
                    await promotions.ReleaseAsync(booking.Id, customerId,
                        "BOOKING_PRICING_REJECTED", operationCt);
                    reservedPromotionBookingId = null;
                    return applied.Error;
                }
            }
            var transitioned = booking.TransitionTo(BookingStatus.PendingPayment);
            if (transitioned.IsFailure)
            {
                if (hasPromotion)
                {
                    await promotions.ReleaseAsync(booking.Id, customerId,
                        "BOOKING_TRANSITION_REJECTED", operationCt);
                    reservedPromotionBookingId = null;
                }
                return transitioned.Error;
            }

            bookings.Add(booking);
            bookingSync.WriteSyncEvent(booking, BookingSyncEventTypes.Created);
            return booking;
        }
    }
}
