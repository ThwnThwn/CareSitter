using CareSitter.Modules.Support.Application.Ports;
using MediatR;

namespace CareSitter.Modules.Support.Application.Commands.Notifications.CompleteNotificationDelivery;

/// <summary>Preserves delivery ownership while reporting provider results.</summary>
internal sealed class CompleteNotificationDeliveryCommandHandler(INotificationDeliveryStore store)
    : IRequestHandler<CompleteNotificationDeliveryCommand, bool>
{
    /// <summary>Accepts only bounded, non-sensitive failure classifications.</summary>
    public Task<bool> Handle(CompleteNotificationDeliveryCommand request, CancellationToken ct) =>
        request.EventId == Guid.Empty || request.ClaimToken == Guid.Empty || request.Channel is not ("push" or "email")
            ? Task.FromResult(false) : store.CompleteAsync(request.EventId, request.Channel, request.ClaimToken,
                request.Succeeded, request.Failure?[..Math.Min(request.Failure.Length, 128)], ct);
}
