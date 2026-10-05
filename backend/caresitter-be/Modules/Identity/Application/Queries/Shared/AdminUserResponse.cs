using CareSitter.SharedKernel.Results;

namespace CareSitter.Modules.Identity.Application;

public sealed record AdminUserResponse(
    Guid Id,
    string Email,
    string? Phone,
    string? DisplayName,
    string? FullName,
    string? AvatarUrl,
    string Status,
    string[] Roles,
    string? AdminDepartment,
    string? AdminRole,
    bool? AdminIsActive,
    DateTimeOffset? LastLoginAt,
    DateTimeOffset CreatedAt,
    DateTimeOffset? UpdatedAt);
