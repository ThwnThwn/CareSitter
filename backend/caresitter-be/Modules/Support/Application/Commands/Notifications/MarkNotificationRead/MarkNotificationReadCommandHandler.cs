using CareSitter.Contracts.Services;
using CareSitter.Modules.Support.Domain;
using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Support.Application.Commands.MarkNotificationRead;

internal sealed class MarkNotificationReadCommandHandler(
    ISupportRepository repository,
    ICurrentUser currentUser)
    : IRequestHandler<MarkNotificationReadCommand, Result<NotificationResponse>>
{
    public async Task<Result<NotificationResponse>> Handle(
        MarkNotificationReadCommand request, CancellationToken ct)
    {
        if (currentUser.UserId is not { } userId) return SupportErrors.Unauthenticated();
        var notification = await repository.GetNotificationAsync(
            request.NotificationId, userId, ct);
        if (notification is null) return SupportErrors.NotFound();
        notification.MarkRead();
        await repository.SaveChangesAsync(ct);
        return SupportResponseMapper.ToResponse(notification);
    }
}
