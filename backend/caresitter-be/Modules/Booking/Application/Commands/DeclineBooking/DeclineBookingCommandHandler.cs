using CareSitter.Contracts.Services;
using CareSitter.Modules.Booking.Domain;
using CareSitter.SharedKernel.Results;
using FluentValidation;
using MediatR;

namespace CareSitter.Modules.Booking.Application.Commands.DeclineBooking;

internal sealed class DeclineBookingCommandHandler(
    IBookingRepository bookings,
    ICurrentUser currentUser,
    IPeopleLookupService people,
    IMatchingService matching,
    IValidator<DeclineBookingCommand> validator,
    IBookingPostCommitService postCommit)
    : IRequestHandler<DeclineBookingCommand, Result<Unit>>
{
    public async Task<Result<Unit>> Handle(DeclineBookingCommand request, CancellationToken ct)
    {
        if (currentUser.UserId is not { } userId) return BookingErrors.Unauthenticated();
        if (!currentUser.IsInRole("CAREGIVER")) return BookingErrors.Forbidden();

        var caregiverId = await people.GetCaregiverProfileIdByUserIdAsync(userId, ct);
        if (caregiverId is null) return BookingErrors.Forbidden();

        var booking = await bookings.GetByIdReadOnlyAsync(request.BookingId, ct);
        if (booking is null) return BookingErrors.NotFound();

        var reason = request.Reason?.Trim();
        var validation = validator.Validate(request with { Reason = reason });
        if (!validation.IsValid)
            return Error.Validation(validation.Errors[0].ErrorCode, validation.Errors[0].ErrorMessage);

        if (booking.CaregiverId.HasValue || booking.Status != BookingStatus.Confirmed)
            return BookingErrors.NotOpenForDecline();

        var assignment = await bookings.GetAssignmentAsync(
            request.BookingId, caregiverId.Value, ct);

        if (assignment is null)
        {
            bookings.AddAssignment(BookingAssignment.CreateRejected(
                request.BookingId, caregiverId.Value, reason));
        }
        else
        {
            assignment.Reject(reason);
        }

        await bookings.SaveChangesAsync(ct);
        await postCommit.RunAsync("declined offer update", () =>
            postCommit.PublishOfferChangedAsync(caregiverId.Value, request.BookingId, "declined", ct));
        var hasActiveOffer = await bookings.HasActiveOfferAsync(
            request.BookingId, DateTimeOffset.UtcNow, ct);
        if (!hasActiveOffer)
            await postCommit.RunAsync("replacement caregiver matching", () =>
                matching.OfferTopCandidatesAsync(request.BookingId, ct));

        return Unit.Value;
    }
}
