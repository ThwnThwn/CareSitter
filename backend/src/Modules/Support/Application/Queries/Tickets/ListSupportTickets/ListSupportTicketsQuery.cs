using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Support.Application;

public sealed record ListSupportTicketsQuery(
    string? Status, string? Type, string? Priority, int Page, int PageSize)
    : IRequest<Result<SupportPage<SupportTicketResponse>>>;
