using CareSitter.Contracts.Services;
using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Payments.Application;

internal static class PaymentPortalErrors
{
    internal static Error Unauthenticated() => Error.Unauthorized(
        "payments.unauthenticated", "Không xác định được người dùng đang đăng nhập.");
    internal static Error Forbidden() => Error.Forbidden(
        "payments.forbidden", "Bạn không có quyền thực hiện thao tác này.");
    internal static Error NotFound() => Error.NotFound(
        "payments.intent_not_found", "Không tìm thấy payment intent.");
}
