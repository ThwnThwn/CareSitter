using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Identity.Application;

public sealed record UpdateNotificationPrefsCommand(NotificationPrefs Preferences)
    : IRequest<Result<NotificationPrefs>>;
