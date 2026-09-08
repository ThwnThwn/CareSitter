using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Identity.Application.UpdateProfile;

public sealed record UpdateProfileCommand(string FullName, string Email, string? DisplayName,
    DateOnly? DateOfBirth, string? Gender) : IRequest<Result<ProfileResponse>>;

public sealed record ProfileResponse(Guid Id, string? Phone, string Email, string FullName,
    string DisplayName, DateOnly? DateOfBirth, string? Gender, Guid? AvatarMediaId,
    Guid? DefaultAddressId, string[] Roles);
