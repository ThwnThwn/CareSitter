using CareSitter.SharedKernel.Results;

namespace CareSitter.Modules.Identity.Application.UpdateProfile;

public sealed record ProfileResponse(Guid Id, string? Phone, string Email, string FullName,
    string DisplayName, DateOnly? DateOfBirth, string? Gender, Guid? AvatarMediaId,
    string? AvatarUrl, Guid? DefaultAddressId, string[] Roles);
