using CareSitter.SharedKernel.Results;

namespace CareSitter.Modules.Identity.Domain.Policies;

internal static class GoogleLoginRolePolicy
{
    public const string Customer = "CUSTOMER";
    public const string Caregiver = "CAREGIVER";

    public static Result<string> Validate(string? requiredRole)
    {
        var normalized = requiredRole?.Trim().ToUpperInvariant();
        return normalized is Customer or Caregiver
            ? Result.Success(normalized)
            : Error.Forbidden(
                "auth.google_role_not_allowed",
                "Google self-registration chỉ hỗ trợ Customer hoặc Caregiver.");
    }
}
