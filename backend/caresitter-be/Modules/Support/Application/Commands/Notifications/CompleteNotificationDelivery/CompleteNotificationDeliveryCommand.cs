using MediatR;

namespace CareSitter.Modules.Support.Application.Commands.Notifications.CompleteNotificationDelivery;

/// <summary>Reports the outcome of one token-fenced channel delivery.</summary>
public sealed record CompleteNotificationDeliveryCommand(Guid EventId, string Channel,
    Guid ClaimToken, bool Succeeded, string? Failure) : IRequest<bool>;
