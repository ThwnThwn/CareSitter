namespace CareSitter.Modules.Identity.Application.Authentication.Dtos.Requests;

public sealed record RegisterRequest(
    string Email,
    string FullName,
    string[] Roles,
    string? Password = null,
    string? ConfirmPassword = null,
    string? Phone = null);
