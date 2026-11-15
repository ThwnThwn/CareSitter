using CareSitter.Modules.Identity.Domain;
using CareSitter.SharedKernel.Results;

namespace CareSitter.Modules.Identity.Application.Login;

internal static class AuthRoleRequirement
{
    private static readonly string[] AllowedRoles = { "CUSTOMER", "CAREGIVER", "ADMIN" };

    public static Result<string?> Normalize(string? requiredRole)
    {
        if (string.IsNullOrWhiteSpace(requiredRole))
        {
            return Result.Success<string?>(null);
        }

        var normalized = requiredRole.Trim().ToUpperInvariant();
        if (!AllowedRoles.Contains(normalized))
        {
            return Error.Validation(
                "auth.invalid_required_role",
                $"Vai trò đăng nhập '{requiredRole}' không hợp lệ.");
        }

        return Result.Success<string?>(normalized);
    }

    public static Result Validate(User user, string? requiredRole)
    {
        var normalizedResult = Normalize(requiredRole);
        if (normalizedResult.IsFailure)
        {
            return normalizedResult.Error;
        }

        var normalized = normalizedResult.Value;
        if (normalized is null)
        {
            return Result.Success();
        }

        if (user.Roles.Any(role => string.Equals(role, normalized, StringComparison.OrdinalIgnoreCase)))
        {
            return Result.Success();
        }

        return Error.Forbidden(
            "auth.role_not_allowed",
            $"Tài khoản này không có quyền đăng nhập ứng dụng {ToDisplayName(normalized)}.");
    }

    private static string ToDisplayName(string role) => role switch
    {
        "CAREGIVER" => "Caregiver",
        "CUSTOMER" => "Customer",
        "ADMIN" => "Admin",
        _ => role
    };
}
