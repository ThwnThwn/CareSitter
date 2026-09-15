using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Support.Application.Commands.MarkAllNotificationsRead;

public sealed record MarkAllNotificationsReadCommand
    : IRequest<Result<MarkedNotificationsResponse>>;
