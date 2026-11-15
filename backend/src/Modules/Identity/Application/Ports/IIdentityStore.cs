using CareSitter.Modules.Identity.Domain;
using CareSitter.SharedKernel.Results;

namespace CareSitter.Modules.Identity.Application;

public interface IIdentityStore
{
    Task<User?> FindUserByIdAsync(Guid userId, CancellationToken ct = default);
    Task<User?> FindUserByEmailAsync(string email, CancellationToken ct = default);
    Task<User?> FindUserByIdentifierAsync(string email, string rawIdentifier,
        CancellationToken ct = default);
    Task<User?> FindUserByGoogleIdOrEmailAsync(string googleId, string email,
        CancellationToken ct = default);
    Task<bool> EmailExistsAsync(string email, Guid? exceptUserId = null,
        CancellationToken ct = default);
    Task<bool> PhoneExistsAsync(string phone, CancellationToken ct = default);
    Task<int> CountActiveAdminsAsync(CancellationToken ct = default);
    Task<IdentityPage<AdminUserResponse>> ListUsersAsync(
        string? query, string? role, string? status, int page, int pageSize,
        CancellationToken ct = default);
    Task<AdminUserResponse?> GetUserResponseAsync(Guid userId, CancellationToken ct = default);
    void AddUser(User user);
    Task SaveChangesAsync(CancellationToken ct = default);
}
