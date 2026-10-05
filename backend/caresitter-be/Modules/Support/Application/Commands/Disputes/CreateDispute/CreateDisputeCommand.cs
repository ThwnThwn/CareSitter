using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Support.Application.Commands.CreateDispute;

public sealed record CreateDisputeCommand(
    Guid BookingId, string? Reason, string? Description)
    : IRequest<Result<DisputeResponse>>;
