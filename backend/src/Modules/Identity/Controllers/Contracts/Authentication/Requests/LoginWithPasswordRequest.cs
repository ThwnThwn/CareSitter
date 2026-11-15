namespace CareSitter.Modules.Identity.Application.Authentication.Dtos.Requests;

public sealed record LoginWithPasswordRequest(string Email, string Password, string? RequiredRole = null);
