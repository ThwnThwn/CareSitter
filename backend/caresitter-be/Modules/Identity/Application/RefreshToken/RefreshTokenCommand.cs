using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Identity.Application.RefreshToken;

/// <summary>
/// Làm mới cặp token (Access + Refresh) từ refresh token hợp lệ đang lưu trong Redis.
/// Chiến lược stateful (Redis-backed):
///   1. Hash refresh token → tìm trong Redis.
///   2. Nếu hợp lệ: lấy userId từ Redis value.
///   3. Kiểm tra user vẫn ACTIVE trong DB.
///   4. Token rotation: xóa key cũ → tạo cặp token mới → lưu key mới vào Redis.
/// Lợi ích so với stateless: logout thật, revoke tức thì, quản lý theo session.
/// </summary>
public sealed record RefreshTokenCommand(string RefreshToken)
    : IRequest<Result<RefreshTokenResponse>>;

public sealed record RefreshTokenResponse(string AccessToken, string RefreshToken);
