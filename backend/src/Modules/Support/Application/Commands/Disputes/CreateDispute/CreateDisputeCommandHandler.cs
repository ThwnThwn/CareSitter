using CareSitter.Contracts.Services;
using CareSitter.Modules.Support.Domain;
using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Support.Application.Commands.CreateDispute;

internal sealed class CreateDisputeCommandHandler(
    ISupportRepository repository,
    ICurrentUser currentUser,
    IDisputeBookingWorkflow bookingWorkflow)
    : IRequestHandler<CreateDisputeCommand, Result<DisputeResponse>>
{
    public async Task<Result<DisputeResponse>> Handle(
        CreateDisputeCommand request, CancellationToken ct)
    {
        if (currentUser.UserId is not { } userId) return SupportErrors.Unauthenticated();
        if (!currentUser.IsInRole("CUSTOMER")) return SupportErrors.Forbidden();

        var booking = await bookingWorkflow.GetAsync(request.BookingId, ct);
        if (booking is null) return SupportErrors.DisputeBookingNotFound();
        if (booking.CustomerId != userId) return SupportErrors.Forbidden();
        var existing = await repository.GetDisputeByBookingAsync(request.BookingId, ct);
        if (existing is not null)
        {
            if (existing.Status == "OPEN" && booking.Status == "disputed" &&
                existing.RaisedByUserId == userId && existing.Reason == request.Reason &&
                existing.Description == request.Description)
                return SupportResponseMapper.ToResponse(existing);
            return SupportErrors.DisputeAlreadyExists();
        }

        var noShowEligible = (booking.Status is "confirmed" or
                "caregiver_accepted" or "caregiver_en_route") &&
            booking.CaregiverId is not null &&
            booking.ActualStart is null &&
            DateTimeOffset.UtcNow >= booking.ScheduledStart.AddMinutes(30);
        if (booking.Status is not ("checkout_pending_review" or "completed") &&
            !noShowEligible)
            return SupportErrors.DisputeInvalidState();
        if (booking.Status == "completed" &&
            (booking.ActualEnd is null ||
             booking.ActualEnd.Value.AddHours(booking.DisputeWindowHours) < DateTimeOffset.UtcNow ||
             booking.SettlementReleasedAt is not null))
            return SupportErrors.DisputeWindowExpired();

        var created = Dispute.Create(request.BookingId, userId,
            request.Reason, request.Description);
        if (created.IsFailure) return created.Error;

        var opened = await bookingWorkflow.OpenAsync(request.BookingId, ct);
        if (opened.IsFailure) return opened.Error;
        repository.AddDispute(created.Value);
        await repository.SaveChangesAsync(ct);
        return SupportResponseMapper.ToResponse(created.Value);
    }
}
