using CareSitter.Contracts.Services;
using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Payments.Application;

public sealed record PaymentPage<T>(IReadOnlyList<T> Items, int Total, int Page, int PageSize);
public sealed record PaymentIntentResponse(
    Guid Id, Guid BookingId, Guid CustomerId, string Provider, long Amount,
    string Currency, string Status, string? ProviderTransactionId,
    string IdempotencyKey, DateTimeOffset CreatedAt,
    string? PaymentUrl = null, string? ProviderOrderRef = null);
public sealed record WalletResponse(
    Guid? Id, long AvailableBalance, long PendingBalance, string Currency);
public sealed record WalletTransactionResponse(
    Guid Id, Guid? BookingId, string TransactionType, long Amount,
    string Currency, string Status, string Direction, DateTimeOffset CreatedAt);
public sealed record LedgerEntryResponse(
    Guid Id, Guid? BookingId, Guid? PaymentIntentId, string TransactionType,
    string DebitAccount, string CreditAccount, long Amount, string Currency,
    string Status, DateTimeOffset CreatedAt);
public sealed record PaymentIntentConflict(
    string Error, string? Code = null,
    DateTimeOffset? PaymentDeadline = null, DateTimeOffset? ExpiresAt = null);
public sealed record PaymentIntentCreationOutcome(
    PaymentIntentResponse? Intent, bool Created, PaymentIntentConflict? Conflict = null);

public sealed record CreatePaymentIntentCommand(Guid BookingId, string? CustomerName)
    : IRequest<Result<PaymentIntentCreationOutcome>>;
public sealed record GetPaymentIntentQuery(Guid IntentId)
    : IRequest<Result<PaymentIntentResponse>>;
public sealed record GetMyWalletQuery : IRequest<Result<WalletResponse>>;
public sealed record ListMyWalletTransactionsQuery(int Page, int PageSize)
    : IRequest<Result<PaymentPage<WalletTransactionResponse>>>;
public sealed record ListLedgerQuery(Guid? BookingId, int Page, int PageSize)
    : IRequest<Result<PaymentPage<LedgerEntryResponse>>>;

public interface IPaymentPortal
{
    Task<Result<PaymentIntentCreationOutcome>> CreateIntentAsync(
        Guid bookingId, Guid userId, string? customerName, CancellationToken ct = default);
    Task<PaymentIntentResponse?> GetIntentAsync(
        Guid intentId, Guid userId, CancellationToken ct = default);
    Task<WalletResponse> GetWalletAsync(
        Guid userId, string accountType, CancellationToken ct = default);
    Task<PaymentPage<WalletTransactionResponse>> ListWalletTransactionsAsync(
        Guid userId, string accountType, int page, int pageSize, CancellationToken ct = default);
    Task<PaymentPage<LedgerEntryResponse>> ListLedgerAsync(
        Guid? bookingId, int page, int pageSize, CancellationToken ct = default);
}

internal static class PaymentPortalErrors
{
    internal static Error Unauthenticated() => Error.Unauthorized(
        "payments.unauthenticated", "Không xác định được người dùng đang đăng nhập.");
    internal static Error Forbidden() => Error.Forbidden(
        "payments.forbidden", "Bạn không có quyền thực hiện thao tác này.");
    internal static Error NotFound() => Error.NotFound(
        "payments.intent_not_found", "Không tìm thấy payment intent.");
}

internal sealed class CreatePaymentIntentCommandHandler(
    IPaymentPortal portal, ICurrentUser currentUser)
    : IRequestHandler<CreatePaymentIntentCommand, Result<PaymentIntentCreationOutcome>>
{
    public Task<Result<PaymentIntentCreationOutcome>> Handle(
        CreatePaymentIntentCommand request, CancellationToken ct) =>
        currentUser.UserId is { } userId
            ? portal.CreateIntentAsync(request.BookingId, userId, request.CustomerName, ct)
            : Task.FromResult<Result<PaymentIntentCreationOutcome>>(
                PaymentPortalErrors.Unauthenticated());
}

internal sealed class GetPaymentIntentQueryHandler(
    IPaymentPortal portal, ICurrentUser currentUser)
    : IRequestHandler<GetPaymentIntentQuery, Result<PaymentIntentResponse>>
{
    public async Task<Result<PaymentIntentResponse>> Handle(
        GetPaymentIntentQuery request, CancellationToken ct)
    {
        if (currentUser.UserId is not { } userId) return PaymentPortalErrors.Unauthenticated();
        var intent = await portal.GetIntentAsync(request.IntentId, userId, ct);
        return intent is null ? PaymentPortalErrors.NotFound() : intent;
    }
}

internal sealed class GetMyWalletQueryHandler(IPaymentPortal portal, ICurrentUser currentUser)
    : IRequestHandler<GetMyWalletQuery, Result<WalletResponse>>
{
    public async Task<Result<WalletResponse>> Handle(GetMyWalletQuery request, CancellationToken ct)
    {
        if (currentUser.UserId is not { } userId) return PaymentPortalErrors.Unauthenticated();
        var type = currentUser.IsInRole("CAREGIVER") ? "CAREGIVER" : "CUSTOMER";
        return await portal.GetWalletAsync(userId, type, ct);
    }
}

internal sealed class ListMyWalletTransactionsQueryHandler(
    IPaymentPortal portal, ICurrentUser currentUser)
    : IRequestHandler<ListMyWalletTransactionsQuery, Result<PaymentPage<WalletTransactionResponse>>>
{
    public async Task<Result<PaymentPage<WalletTransactionResponse>>> Handle(
        ListMyWalletTransactionsQuery request, CancellationToken ct)
    {
        if (currentUser.UserId is not { } userId) return PaymentPortalErrors.Unauthenticated();
        var type = currentUser.IsInRole("CAREGIVER") ? "caregiver" : "customer";
        return await portal.ListWalletTransactionsAsync(userId, type,
            Math.Max(request.Page, 1), Math.Clamp(request.PageSize, 1, 50), ct);
    }
}

internal sealed class ListLedgerQueryHandler(IPaymentPortal portal, ICurrentUser currentUser)
    : IRequestHandler<ListLedgerQuery, Result<PaymentPage<LedgerEntryResponse>>>
{
    public async Task<Result<PaymentPage<LedgerEntryResponse>>> Handle(
        ListLedgerQuery request, CancellationToken ct)
    {
        if (!currentUser.IsInRole("ADMIN")) return PaymentPortalErrors.Forbidden();
        if (currentUser.UserId is null) return PaymentPortalErrors.Unauthenticated();
        return await portal.ListLedgerAsync(request.BookingId, Math.Max(request.Page, 1),
            Math.Clamp(request.PageSize, 1, 50), ct);
    }
}
