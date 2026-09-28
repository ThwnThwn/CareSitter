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
        if (booking.Status is not ("checkout_pending_review" or "completed"))
            return SupportErrors.DisputeInvalidState();
        if (booking.Status == "completed" &&
            (booking.ActualEnd is null ||
             booking.ActualEnd.Value.AddHours(booking.DisputeWindowHours) < DateTimeOffset.UtcNow ||
             booking.SettlementReleasedAt is not null))
            return SupportErrors.DisputeWindowExpired();

        var exists = await repository.DisputeExistsAsync(request.BookingId, ct);
        if (exists) return SupportErrors.DisputeAlreadyExists();

        var created = Dispute.Create(request.BookingId, userId,
            request.Reason, request.Description);
        if (created.IsFailure) return created.Error;

        repository.AddDispute(created.Value);
        await repository.SaveChangesAsync(ct);

        var opened = await bookingWorkflow.OpenAsync(request.BookingId, ct);
        if (opened.IsFailure)
        {
            created.Value.Cancel();
            await repository.SaveChangesAsync(ct);
            return opened.Error;
        }
        return SupportResponseMapper.ToResponse(created.Value);
    }
}
