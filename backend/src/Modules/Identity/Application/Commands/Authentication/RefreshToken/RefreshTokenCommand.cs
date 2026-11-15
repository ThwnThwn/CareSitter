using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Identity.Application.RefreshToken;

/// <summary>
/// Làm mới cặp token (Access + Refresh) từ refresh session bền vững trong PostgreSQL.
/// Redis chỉ là lookup cache; cache miss hoặc restart không làm mất phiên đăng nhập.
/// Rotation revoke bản ghi cũ và tạo session mới trong cùng transaction.
/// </summary>
public sealed record RefreshTokenCommand(string RefreshToken)
    : IRequest<Result<RefreshTokenResponse>>;
