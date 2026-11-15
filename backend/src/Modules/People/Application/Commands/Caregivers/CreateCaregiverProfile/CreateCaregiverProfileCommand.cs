using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.People.Application.Commands.CreateCaregiverProfile;

public sealed record CreateCaregiverProfileCommand(string? FullName)
    : IRequest<Result<CaregiverProfileCreationResponse>>;
