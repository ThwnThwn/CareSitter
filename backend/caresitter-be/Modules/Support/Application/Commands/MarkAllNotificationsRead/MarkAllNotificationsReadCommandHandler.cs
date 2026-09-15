using CareSitter.Infrastructure.Security;
using CareSitter.Modules.Support.Domain;
using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Support.Application.Commands.MarkAllNotificationsRead;

internal sealed class MarkAllNotificationsReadCommandHandler(
    ISupportRepository repository,
    ICurrentUser currentUser)
    : IRequestHandler<MarkAllNotificationsReadCommand, Result<MarkedNotificationsResponse>>
{
    public async Task<Result<MarkedNotificationsResponse>> Handle(
        MarkAllNotificationsReadCommand request, CancellationToken ct)
    {
        if (currentUser.UserId is not { } userId) return SupportErrors.Unauthenticated();
        var unread = await repository.GetUnreadNotificationsAsync(userId, ct);
        foreach (var notification in unread) notification.MarkRead();
        await repository.SaveChangesAsync(ct);
        return new MarkedNotificationsResponse(unread.Count);
    }
}
