using CareSitter.SharedKernel.Results;

namespace CareSitter.Modules.Payments.Application.Payouts;

internal static class PayoutErrors
{
    public const string UnauthenticatedCode = "payout.unauthenticated";
    public const string WalletNotFoundCode = "payout.wallet_not_found";
    public const string InsufficientBalanceCode = "payout.insufficient_balance";
    public const string NotFoundCode = "payout.not_found";
    public const string InvalidBalanceCode = "payout.balance";

    public static Error Unauthenticated() => Error.Unauthorized(
        UnauthenticatedCode, "Không xác định được người dùng.");

    public static Error Forbidden() => Error.Forbidden(
        "payout.forbidden", "Bạn không có quyền thực hiện thao tác này.");

    public static Error WalletNotFound() => Error.Validation(
        WalletNotFoundCode, "Caregiver chưa có ví điện tử.");

    public static Error InsufficientBalance() => Error.Validation(
        InsufficientBalanceCode, "Số dư khả dụng không đủ.");

    public static Error NotFound() => Error.NotFound(
        NotFoundCode, "Không tìm thấy yêu cầu rút tiền.");

    public static Error InvalidBalance() => Error.Conflict(
        InvalidBalanceCode, "Số dư tạm giữ không còn hợp lệ.");
}
