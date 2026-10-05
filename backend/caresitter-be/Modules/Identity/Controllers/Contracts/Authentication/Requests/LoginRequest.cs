namespace CareSitter.Modules.Identity.Application.Authentication.Dtos.Requests;

public sealed record LoginRequest(string Email, string Otp, string? RequiredRole = null);
