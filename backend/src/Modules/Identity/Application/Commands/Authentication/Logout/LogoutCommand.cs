using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Identity.Application.Logout;

/// <summary>
/// Yêu cầu đăng xuất:
///   1. Đưa JWT ID (jti) của access token vào blacklist cho đến khi token hết hạn.
///   2. (Nếu có RefreshToken) Revoke refresh session trong PostgreSQL,
///      token cũ không thể dùng để refresh nữa dù chưa hết TTL.
/// </summary>
/// <param name="Jti">JWT ID của access token hiện tại.</param>
/// <param name="ExpiresAtUtc">Thời điểm hết hạn của access token hiện tại.</param>
/// <param name="UserId">User sở hữu access token hiện tại.</param>
/// <param name="SessionId">Phiên PostgreSQL được bind trong claim sid.</param>
/// <param name="RefreshToken">Raw refresh token (tùy chọn). Chỉ hash của token được dùng để tìm và revoke session.</param>
public sealed record LogoutCommand(
    string Jti,
    DateTimeOffset ExpiresAtUtc,
    Guid UserId,
    Guid SessionId,
    string? RefreshToken = null) : IRequest<Result>;
