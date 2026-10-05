using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Support.Application;

public sealed record GetSupportTicketQuery(Guid TicketId) : IRequest<Result<SupportTicketResponse>>;
