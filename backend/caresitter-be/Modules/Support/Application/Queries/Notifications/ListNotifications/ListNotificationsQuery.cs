using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Support.Application;

public sealed record ListNotificationsQuery(
    int Page, int PageSize) : IRequest<Result<SupportPage<NotificationResponse>>>;
