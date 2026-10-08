using CareSitter.Modules.Identity.Domain;
using CareSitter.SharedKernel.Results;

namespace CareSitter.Modules.Identity.Application;

public sealed class AuthenticationStateChangedException : Exception;

public static class SessionIssuance
{
    public static async Task<Result<IssuedTokenPair>> TryIssueAsync(this IRefreshTokenSessionService sessions,
        User user, CancellationToken ct)
    {
        try { return await sessions.IssueAsync(user, ct); }
        catch (AuthenticationStateChangedException)
        { return Error.Validation("auth.state_changed", "Thông tin bảo mật đã thay đổi. Vui lòng đăng nhập lại."); }
    }
}
