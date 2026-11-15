using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.People.Application.Commands.UpdateCaregiverProfile;

public sealed record UpdateCaregiverProfileCommand(string? FullName, string? Bio,
    int? YearsOfExperience, string? Skills, string? ServiceCity,
    string? ServiceDistrict, string? Gender, DateOnly? DateOfBirth)
    : IRequest<Result<CaregiverProfileUpdateResponse>>;
