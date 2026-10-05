using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Support.Application.Commands.MarkNotificationRead;

public sealed record MarkNotificationReadCommand(Guid NotificationId)
    : IRequest<Result<NotificationResponse>>;
