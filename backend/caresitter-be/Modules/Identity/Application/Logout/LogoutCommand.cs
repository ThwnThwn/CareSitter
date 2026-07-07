using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Identity.Application.Logout;

/// <summary>
/// Yêu cầu đăng xuất token hiện tại bằng cách đưa JWT ID (jti) vào blacklist cho đến khi token hết hạn.
/// </summary>
/// <param name="Jti">JWT ID của access token hiện tại.</param>
/// <param name="ExpiresAtUtc">Thời điểm hết hạn của access token hiện tại.</param>
public sealed record LogoutCommand(string Jti, DateTimeOffset ExpiresAtUtc) : IRequest<Result>;
