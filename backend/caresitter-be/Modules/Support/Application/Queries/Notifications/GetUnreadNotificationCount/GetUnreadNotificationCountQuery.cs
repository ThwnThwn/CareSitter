using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Support.Application;

public sealed record GetUnreadNotificationCountQuery : IRequest<Result<UnreadNotificationCountResponse>>;
