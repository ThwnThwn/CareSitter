namespace CareSitter.Modules.Identity.Application.Profile.Dtos.Requests;

public sealed record UpdateProfileRequest(string FullName, string Email, string? DisplayName,
    DateOnly? DateOfBirth, string? Gender);
