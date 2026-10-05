using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.People.Application.Commands.UpdateCaregiverAvailabilityStatus;

public sealed record UpdateCaregiverAvailabilityStatusCommand(string Status)
    : IRequest<Result<CaregiverAvailabilityResponse>>;
