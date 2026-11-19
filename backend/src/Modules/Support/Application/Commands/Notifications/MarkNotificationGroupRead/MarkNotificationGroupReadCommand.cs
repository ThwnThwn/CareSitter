using CareSitter.Contracts.Services;
using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Support.Application.Commands;

public sealed record MarkNotificationGroupReadCommand(Guid NotificationId)
    : IRequest<Result<MarkedNotificationsResponse>>;

internal sealed class MarkNotificationGroupReadCommandHandler(
    INotificationInboxStore store, ICurrentUser currentUser)
    : IRequestHandler<MarkNotificationGroupReadCommand, Result<MarkedNotificationsResponse>>
{
    public async Task<Result<MarkedNotificationsResponse>> Handle(
        MarkNotificationGroupReadCommand request, CancellationToken ct)
    {
        if (currentUser.UserId is not { } userId) return SupportErrors.Unauthenticated();
        var count = await store.MarkGroupReadAsync(userId, request.NotificationId, ct);
        return new MarkedNotificationsResponse(count);
    }
}
