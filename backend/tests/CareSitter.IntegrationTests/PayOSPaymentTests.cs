using System.Collections.Concurrent;
using System.Globalization;
using System.Text.Json;
using System.Net;
using System.Net.Http.Json;
using System.Security.Claims;
using System.Text.Encodings.Web;
using CareSitter.Contracts.IntegrationEvents;
using CareSitter.Contracts.Services;
using SystemClock = CareSitter.Infrastructure.Time.SystemClock;
using CareSitter.Modules.Payments;
using CareSitter.Modules.Booking.Infrastructure;
using CareSitter.Modules.Booking.Domain;
using CareSitter.Modules.Payments.Application;
using CareSitter.Modules.Payments.Domain;
using CareSitter.Modules.Payments.Infrastructure;
using CareSitter.Modules.Payments.Controllers;
using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.TestHost;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging.Abstractions;
using Microsoft.Extensions.Options;
using Npgsql;

namespace CareSitter.IntegrationTests;

[Trait("Category", "PostgreSQL")]
public sealed class PayOSPaymentTests : IAsyncLifetime
{
    private PostgresRaceTestDatabase _database = null!;
    private readonly FakeBank _bank = new();
    public async Task InitializeAsync()
    {
        if (!string.IsNullOrWhiteSpace(Environment.GetEnvironmentVariable(PostgresFactAttribute.ConnectionVariable)))
            _database = await PostgresRaceTestDatabase.CreateAsync();
    }
    public async Task DisposeAsync() { if (_database is not null) await _database.DisposeAsync(); }

    [PostgresFact]
    public async Task Concurrent_payOS_requests_reuse_one_persisted_order_and_checkout()
    {
        var booking = await CreateBookingAsync();
        var responses = await Task.WhenAll(Enumerable.Range(0, 12).Select(async _ =>
        {
            await using var scope = Scope();
            return await scope.PayOS.CreateIntentAsync(booking.Id, booking.CustomerId);
        }));
        Assert.All(responses, response => Assert.True(response.IsSuccess));
        var ids = responses.Select(x => x.Value.Intent!.Id).Distinct().ToArray();
        Assert.Single(ids);
        Assert.Single(_bank.Links);
        await using var verify = Scope();
        Assert.Single(await verify.Payments.PaymentIntents.ToListAsync());
        Assert.Equal(100000, responses[0].Value.Intent!.Amount);
        Assert.All(responses, x => Assert.Equal("https://pay.payos.vn/web/" + ids[0].ToString("N"), x.Value.Intent!.PaymentUrl));
    }

    [PostgresFact]
    public async Task Concurrent_VNPAY_and_PAYOS_requests_cannot_open_two_gateways()
    {
        var booking = await CreateBookingAsync();
        var responses = await Task.WhenAll(new[] { "PAYOS", "VNPAY" }.Select(async provider =>
        {
            await using var scope = Scope();
            return await scope.Portal.CreateIntentAsync(booking.Id, booking.CustomerId, "Customer", provider: provider);
        }));
        Assert.Single(responses, x => x.IsSuccess && x.Value.Intent is not null);
        Assert.Single(responses, x => x.IsSuccess && x.Value.Conflict?.Code == "PAYMENT_PROVIDER_IN_PROGRESS");
        await using var verify = Scope();
        Assert.Single(await verify.Payments.PaymentIntents.ToListAsync());
    }

    [PostgresFact]
    public async Task Response_loss_recovers_original_order_without_a_second_payment_link()
    {
        var booking = await CreateBookingAsync();
        _bank.LoseResponse = true;
        await using var scope = Scope();
        var first = await scope.PayOS.CreateIntentAsync(booking.Id, booking.CustomerId);
        var retry = await scope.PayOS.CreateIntentAsync(booking.Id, booking.CustomerId);
        Assert.True(first.IsSuccess);
        Assert.Equal(first.Value.Intent!.Id, retry.Value.Intent!.Id);
        Assert.Single(_bank.Links);
        Assert.Equal(1, _bank.CreateCalls);
    }

    [PostgresFact]
    public async Task Concurrent_duplicate_webhooks_confirm_once_and_write_one_ledger_and_outbox()
    {
        var booking = await CreateBookingAsync();
        var intent = await CreateIntentAsync(booking);
        _bank.Paid = intent.Amount;
        var payload = _bank.Webhook(intent, "bank-reference-1");
        var outcomes = await Task.WhenAll(Enumerable.Range(0, 12).Select(async _ =>
        {
            await using var scope = Scope();
            return await scope.PayOS.ProcessWebhookAsync(payload);
        }));
        Assert.All(outcomes, outcome => Assert.Equal(200, outcome.StatusCode));
        await using var verify = Scope();
        Assert.Equal("SUCCEEDED", (await verify.Payments.PaymentIntents.SingleAsync()).Status);
        Assert.Single(await verify.Payments.LedgerEntries.ToListAsync());
        Assert.Single(await verify.Payments.OutboxMessages.ToListAsync());
        Assert.Equal("PROCESSED", (await verify.Payments.PaymentWebhooks.SingleAsync()).Status);
        Assert.Equal(BookingStatus.Confirmed, (await verify.Bookings.Bookings.SingleAsync(x => x.Id == booking.Id)).Status);
    }

    [PostgresFact]
    public async Task Invalid_signature_and_unknown_probe_cannot_credit_a_booking()
    {
        var booking = await CreateBookingAsync();
        var intent = await CreateIntentAsync(booking);
        var payload = _bank.Webhook(intent, "bad-signature");
        var forged = JsonDocument.Parse(payload.GetRawText().Replace("100000", "999999")).RootElement;
        await using var scope = Scope();
        Assert.Equal(400, (await scope.PayOS.ProcessWebhookAsync(forged)).StatusCode);
        Assert.Equal(200, (await scope.PayOS.ProcessWebhookAsync(_bank.Webhook(intent, "registration-probe", orderCode: 1))).StatusCode);
        Assert.Empty(await scope.Payments.LedgerEntries.ToListAsync());
        Assert.Empty(await scope.Payments.PaymentWebhooks.ToListAsync());
        Assert.Equal("PENDING", (await scope.Payments.PaymentIntents.SingleAsync()).Status);
    }

    [PostgresFact]
    public async Task Signed_callback_accepts_sender_account_that_differs_from_merchant_account()
    {
        var booking = await CreateBookingAsync();
        var intent = await CreateIntentAsync(booking);
        _bank.Paid = intent.Amount;
        await using var scope = Scope();

        // payOS callback accountNumber identifies the sender, not the merchant
        // receiving account returned by create-link. It may legitimately differ.
        var outcome = await scope.PayOS.ProcessWebhookAsync(
            _bank.Webhook(intent, "different-sender", accountNumber: "other-account"));

        Assert.Equal(200, outcome.StatusCode);
        Assert.Single(await scope.Payments.LedgerEntries.ToListAsync());
        Assert.Single(await scope.Payments.PaymentWebhooks.ToListAsync());
        Assert.Equal("SUCCEEDED", (await scope.Payments.PaymentIntents.SingleAsync()).Status);
    }

    [PostgresFact]
    public async Task Partial_payment_is_acknowledged_for_review_then_full_total_confirms_once()
    {
        var booking = await CreateBookingAsync();
        var intent = await CreateIntentAsync(booking);
        _bank.Paid = 30000;
        await using var scope = Scope();
        Assert.Equal(200, (await scope.PayOS.ProcessWebhookAsync(_bank.Webhook(intent, "partial", amount: 30000))).StatusCode);
        Assert.Empty(await scope.Payments.LedgerEntries.ToListAsync());
        scope.Bookings.ChangeTracker.Clear();
        Assert.Equal(BookingStatus.NeedsManualReview, (await scope.Bookings.Bookings.SingleAsync(x => x.Id == booking.Id)).Status);
        _bank.Paid = 100000;
        Assert.Equal(200, (await scope.PayOS.ProcessWebhookAsync(_bank.Webhook(intent, "remaining", amount: 70000))).StatusCode);
        Assert.Single(await scope.Payments.LedgerEntries.ToListAsync());
        Assert.Equal("SUCCEEDED", (await scope.Payments.PaymentIntents.SingleAsync()).Status);
    }

    [PostgresFact]
    public async Task Browser_return_and_customer_access_require_authoritative_provider_status_and_ownership()
    {
        var booking = await CreateBookingAsync();
        var intent = await CreateIntentAsync(booking);
        await using var scope = Scope();
        var url = await scope.PayOS.GetReturnUrlAsync(intent.ProviderOrderRef);
        Assert.Contains("result=pending", url);
        Assert.Contains("intentId=" + intent.Id, url);
        Assert.Empty(await scope.Payments.LedgerEntries.ToListAsync());
        Assert.Null(await scope.Portal.GetIntentAsync(intent.Id, Guid.NewGuid()));
        _bank.Paid = 100000;
        var result = await scope.Portal.GetIntentAsync(intent.Id, booking.CustomerId);
        Assert.Equal("SUCCEEDED", result!.Status);
        Assert.Single(await scope.Payments.LedgerEntries.ToListAsync());
    }

    [PostgresFact]
    public async Task Late_payment_remains_visible_to_admin_without_reopening_a_closed_booking()
    {
        var booking = await CreateBookingAsync();
        var intent = await CreateIntentAsync(booking);
        await using var scope = Scope();
        var tracked = await scope.Payments.PaymentIntents.SingleAsync();
        tracked.MarkFailed(); await scope.Payments.SaveChangesAsync();
        var closed = await scope.Bookings.Bookings.SingleAsync(x => x.Id == booking.Id);
        Assert.True(closed.Cancel(booking.CustomerId, "CUSTOMER", "Test cancellation", DateTimeOffset.UtcNow).IsSuccess);
        await scope.Bookings.SaveChangesAsync();
        _bank.Paid = 100000;
        Assert.Equal(200, (await scope.PayOS.ProcessWebhookAsync(_bank.Webhook(intent, "late-payment"))).StatusCode);
        Assert.Empty(await scope.Payments.LedgerEntries.ToListAsync());
        Assert.Equal(BookingStatus.Cancelled, closed.Status);
        var queue = await new PaymentReconciliationProcessor(scope.Payments, scope.Gateway, scope.Finalizer, scope.Outbox, new Audit())
            .ListAsync();
        Assert.Single(queue); Assert.False(queue[0].CanResolve);
        Assert.Contains("PAYOS_LATE_PAYMENT", queue[0].ManualReviewReason);
        var rejected = await new PaymentReconciliationProcessor(scope.Payments, scope.Gateway, scope.Finalizer, scope.Outbox, new Audit())
            .ResolveAsync(new ResolvePaymentReviewCommand(intent.Id, true, "Test cannot reopen", "bank-reference"));
        Assert.True(rejected.IsFailure);
        Assert.Empty(await scope.Payments.LedgerEntries.ToListAsync());
    }

    [PostgresFact]
    public async Task A_second_actual_bank_transfer_is_flagged_without_double_credit()
    {
        var booking = await CreateBookingAsync();
        var intent = await CreateIntentAsync(booking);
        _bank.Paid = 100000;
        await using var scope = Scope();
        await scope.PayOS.ProcessWebhookAsync(_bank.Webhook(intent, "first-transfer"));
        _bank.Paid = 200000;
        Assert.Equal(200, (await scope.PayOS.ProcessWebhookAsync(_bank.Webhook(intent, "second-transfer"))).StatusCode);
        Assert.Single(await scope.Payments.LedgerEntries.ToListAsync());
        var queue = await new PaymentReconciliationProcessor(scope.Payments, scope.Gateway, scope.Finalizer, scope.Outbox, new Audit()).ListAsync();
        Assert.Single(queue); Assert.False(queue[0].CanResolve);
        Assert.Contains("PAYOS_ADDITIONAL_PAYMENT", queue[0].ManualReviewReason);
    }

    [PostgresFact]
    public async Task Disabled_payOS_and_foreign_customer_do_not_create_payment_links()
    {
        var booking = await CreateBookingAsync();
        await using var scope = Scope(enabled: false);
        var disabled = await scope.PayOS.CreateIntentAsync(booking.Id, booking.CustomerId);
        Assert.True(disabled.IsFailure);
        await using var enabled = Scope();
        var foreign = await enabled.PayOS.CreateIntentAsync(booking.Id, Guid.NewGuid());
        Assert.True(foreign.IsFailure);
        Assert.Empty(_bank.Links);
    }

    [PostgresFact]
    public async Task HTTP_API_enforces_authentication_ownership_server_amount_and_signed_webhook()
    {
        var booking = await CreateBookingAsync();
        var builder = WebApplication.CreateBuilder();
        builder.WebHost.UseTestServer();
        builder.Services.AddAuthentication("test").AddScheme<AuthenticationSchemeOptions, HeaderAuth>("test", _ => { });
        builder.Services.AddAuthorization();
        builder.Services.AddHttpContextAccessor();
        builder.Services.AddScoped<ICurrentUser, RequestUser>();
        builder.Services.AddScoped(_ => Scope());
        builder.Services.AddScoped<IPaymentPortal>(sp => sp.GetRequiredService<TestScope>().Portal);
        builder.Services.AddScoped<IPayOSPaymentPortal>(sp => sp.GetRequiredService<TestScope>().PayOS);
        builder.Services.Configure<PayOSOptions>(options => options.Enabled = true);
        builder.Services.Configure<VNPayOptions>(_ => { });
        builder.Services.AddMediatR(config => config.RegisterServicesFromAssemblyContaining<PaymentsModule>());
        builder.Services.AddControllers().AddApplicationPart(typeof(PayOSController).Assembly);
        await using var app = builder.Build();
        app.UseAuthentication(); app.UseAuthorization(); app.MapControllers();
        await app.StartAsync();
        using var client = app.GetTestClient();
        var denied = await client.PostAsJsonAsync("/api/v1/payments/intents", new { bookingId = booking.Id, provider = "PAYOS" });
        Assert.Equal(HttpStatusCode.Unauthorized, denied.StatusCode);
        client.DefaultRequestHeaders.Add("x-test-user", booking.CustomerId.ToString());
        var providers = await client.GetFromJsonAsync<PaymentProviderResponse[]>("/api/v1/payments/providers");
        Assert.Contains(providers!, x => x.Code == "PAYOS" && x.Enabled);
        var created = await client.PostAsJsonAsync("/api/v1/payments/intents", new { bookingId = booking.Id, provider = "PAYOS", amount = 1 });
        Assert.Equal(HttpStatusCode.Created, created.StatusCode);
        using var body = JsonDocument.Parse(await created.Content.ReadAsStringAsync());
        Assert.Equal(100000, body.RootElement.GetProperty("amount").GetInt64());
        var id = body.RootElement.GetProperty("id").GetGuid();
        client.DefaultRequestHeaders.Remove("x-test-user");
        client.DefaultRequestHeaders.Add("x-test-user", Guid.NewGuid().ToString());
        Assert.Equal(HttpStatusCode.NotFound, (await client.GetAsync("/api/v1/payments/intents/" + id)).StatusCode);
        client.DefaultRequestHeaders.Remove("x-test-user");
        await using var scope = Scope();
        var intent = await scope.Payments.PaymentIntents.AsNoTracking().SingleAsync();
        _bank.Paid = 100000;
        var webhook = _bank.Webhook(intent, "http-webhook");
        Assert.Equal(HttpStatusCode.OK, (await client.PostAsJsonAsync("/api/v1/payments/payos/webhook", webhook)).StatusCode);
        var bad = JsonDocument.Parse(webhook.GetRawText().Replace("100000", "999999")).RootElement;
        Assert.Equal(HttpStatusCode.BadRequest, (await client.PostAsJsonAsync("/api/v1/payments/payos/webhook", bad)).StatusCode);
        Assert.Single(await scope.Payments.LedgerEntries.ToListAsync());
        await app.StopAsync();
    }

    [PostgresFact]
    public async Task Deadline_job_queries_payOS_before_finalizing_or_expiring_booking()
    {
        var booking = await CreateBookingAsync();
        await CreateIntentAsync(booking);
        await using var connection = await _database.OpenConnectionAsync();
        await using var overdue = new NpgsqlCommand("UPDATE booking.bookings SET payment_deadline = now() - interval '1 minute' WHERE id = @id", connection);
        overdue.Parameters.AddWithValue("id", booking.Id); await overdue.ExecuteNonQueryAsync();
        _bank.Paid = 100000;
        await using var scope = Scope();
        var timing = Options.Create(new VNPayOptions { MaxReconciliationAttempts = 3, ReconciliationWindowMinutes = 15 });
        var job = new PaymentReconciliationJob(scope.Payments, scope.Gateway,
            new PaymentStatusGateway(new FakeVNPay(), _bank, timing), timing,
            scope.Finalizer, scope.Outbox, new SystemClock(), NullLogger<PaymentReconciliationJob>.Instance);
        await job.ExecuteAsync();
        Assert.Equal("SUCCEEDED", (await scope.Payments.PaymentIntents.SingleAsync()).Status);
        Assert.Single(await scope.Payments.LedgerEntries.ToListAsync());
        scope.Bookings.ChangeTracker.Clear();
        Assert.Equal(BookingStatus.Confirmed, (await scope.Bookings.Bookings.SingleAsync(x => x.Id == booking.Id)).Status);
    }

    private TestScope Scope(bool enabled = true) => new(_database.ConnectionString, _bank, enabled);
    private async Task<PaymentIntent> CreateIntentAsync(BookingRecord booking)
    {
        await using var scope = Scope();
        var result = await scope.PayOS.CreateIntentAsync(booking.Id, booking.CustomerId);
        Assert.True(result.IsSuccess);
        Assert.NotNull(result.Value.Intent);
        return await scope.Payments.PaymentIntents.AsNoTracking().SingleAsync();
    }
    private async Task<BookingRecord> CreateBookingAsync()
    {
        var id = Guid.NewGuid();
        await using var connection = await _database.OpenConnectionAsync();
        await using var command = new NpgsqlCommand("""
            INSERT INTO booking.bookings (id, customer_id, beneficiary_id, address_id, service_type_id,
                scheduled_start, scheduled_end, payment_deadline, status,
                escrow_amount, platform_fee_amount, caregiver_earning_amount)
            SELECT @id, beneficiary.customer_id, beneficiary.id, address.id, service.id,
                now() + interval '2 days', now() + interval '2 days 2 hours', now() + interval '30 minutes',
                'PENDING_PAYMENT', 100000, 15000, 85000
            FROM people.beneficiaries beneficiary
            JOIN catalog.addresses address ON address.owner_user_id = beneficiary.customer_id
            CROSS JOIN LATERAL (SELECT id FROM catalog.service_types ORDER BY id LIMIT 1) service
            ORDER BY beneficiary.id, address.id LIMIT 1 RETURNING customer_id
            """, connection);
        command.Parameters.AddWithValue("id", id);
        return new(id, (Guid)(await command.ExecuteScalarAsync())!);
    }
    private sealed record BookingRecord(Guid Id, Guid CustomerId);

    private sealed class TestScope : IAsyncDisposable
    {
        public PaymentsDbContext Payments { get; }
        public BookingDbContext Bookings { get; }
        public BookingPaymentGateway Gateway { get; }
        public IPaymentOutboxDispatcher Outbox { get; }
        public PaymentFinalizationService Finalizer { get; }
        public PayOSPaymentPortal PayOS { get; }
        public PaymentPortal Portal { get; }
        public TestScope(string connection, FakeBank bank, bool enabled)
        {
            Payments = new(new DbContextOptionsBuilder<PaymentsDbContext>().UseNpgsql(connection).Options);
            Bookings = new(new DbContextOptionsBuilder<BookingDbContext>().UseNpgsql(connection).Options);
            Gateway = new(Bookings);
            Outbox = new BookingDispatcher(Payments, Bookings);
            Finalizer = new(Payments, Outbox, new Audit(), NullLogger<PaymentFinalizationService>.Instance);
            var timing = Options.Create(new VNPayOptions { TmnCode = "test", HashSecret = "test", ReconciliationWindowMinutes = 15 });
            PayOS = new(Payments, Gateway, bank, Finalizer, Outbox, Options.Create(new PayOSOptions { Enabled = enabled }), timing, new SystemClock());
            Portal = new(Payments, Gateway, new FakeVNPay(), Finalizer, Outbox, PayOS, timing, new SystemClock());
        }
        public async ValueTask DisposeAsync() { await Payments.DisposeAsync(); await Bookings.DisposeAsync(); }
    }

    private sealed class FakeBank : IPayOSService
    {
        public const string Checksum = "test-checksum-key-with-more-than-32-characters";
        public readonly ConcurrentDictionary<string, PayOSPaymentLink> Links = new();
        public long Paid;
        public bool LoseResponse;
        public int CreateCalls;
        public Task<PayOSPaymentLink> CreateLinkAsync(PaymentIntent intent, CancellationToken ct = default)
        {
            Interlocked.Increment(ref CreateCalls);
            var link = Links.GetOrAdd(intent.ProviderOrderRef!, _ => new(long.Parse(intent.ProviderOrderRef!), intent.Amount,
                intent.Id.ToString("N"), "https://pay.payos.vn/web/" + intent.Id.ToString("N"), "12345678", "{}"));
            if (LoseResponse) { LoseResponse = false; throw new HttpRequestException("Simulated response loss"); }
            return Task.FromResult(link);
        }
        public Task<PaymentProviderQuery> QueryAsync(PaymentIntent intent, CancellationToken ct = default)
        {
            var id = Links.GetValueOrDefault(intent.ProviderOrderRef!)?.PaymentLinkId;
            return Task.FromResult(new PaymentProviderQuery(Paid == intent.Amount ? PaymentProviderState.Succeeded :
                Paid > intent.Amount ? PaymentProviderState.Unknown : PaymentProviderState.Processing, id, "{}"));
        }
        public bool VerifyWebhook(JsonElement payload) => PayOSSignature.Verify(payload.GetProperty("data"),
            payload.GetProperty("signature").GetString(), Checksum);
        public JsonElement Webhook(PaymentIntent intent, string reference, long? amount = null,
            string accountNumber = "12345678", long? orderCode = null)
        {
            var data = JsonSerializer.SerializeToElement(new { orderCode = orderCode ?? long.Parse(intent.ProviderOrderRef!, CultureInfo.InvariantCulture),
                amount = amount ?? intent.Amount, paymentLinkId = Links[intent.ProviderOrderRef!].PaymentLinkId,
                reference, accountNumber, currency = "VND", code = "00" });
            return JsonSerializer.SerializeToElement(new { code = "00", success = true, data,
                signature = PayOSSignature.Sign(PayOSSignature.Canonicalize(data), Checksum) });
        }
    }
    private sealed class FakeVNPay : IVNPayService
    {
        public string BuildPaymentUrl(PaymentIntent intent, VNPayOptions options, string? bookingCustomerName = null) =>
            "https://sandbox.vnpayment.vn/paymentv2/vpcpay.html?reference=" + intent.Id;
        public bool VerifyCallback(IReadOnlyDictionary<string, string> values, VNPayOptions options) => false;
        public Task<VNPayQueryResult> QueryTransactionAsync(PaymentIntent intent, VNPayOptions options, CancellationToken ct = default) =>
            Task.FromResult(new VNPayQueryResult(VNPayQueryState.Processing, null, "00", "01", "{}", null));
    }
    private sealed class Audit : IAuditLogger
    {
        public Task WriteAsync(string action, string entityType, Guid entityId, object? before, object? after,
            CancellationToken ct = default) => Task.CompletedTask;
    }
    private sealed class BookingDispatcher(PaymentsDbContext payments, BookingDbContext bookings) : IPaymentOutboxDispatcher
    {
        public async Task DispatchAsync(Guid messageId, CancellationToken ct = default)
        {
            var message = await payments.OutboxMessages.SingleAsync(x => x.Id == messageId, ct);
            var eventData = JsonDocument.Parse(message.Payload).RootElement;
            var bookingId = eventData.GetProperty("BookingId").GetGuid();
            bookings.ChangeTracker.Clear();
            await using var tx = await bookings.Database.BeginTransactionAsync(ct);
            var booking = await bookings.Bookings.FromSqlInterpolated(
                $"SELECT * FROM booking.bookings WHERE id = {bookingId} FOR UPDATE").SingleAsync(ct);
            if (message.Type == typeof(PaymentSucceeded).FullName && booking.Status != BookingStatus.Confirmed)
                Assert.True(booking.ConfirmPayment().IsSuccess);
            if (message.Type == typeof(PaymentReconciliationStarted).FullName && booking.Status == BookingStatus.PendingPayment)
                Assert.True(booking.BeginPaymentReconciliation().IsSuccess);
            if (message.Type == typeof(PaymentNeedsManualReview).FullName)
            {
                if (booking.Status == BookingStatus.PendingPayment) Assert.True(booking.BeginPaymentReconciliation().IsSuccess);
                if (booking.Status == BookingStatus.PaymentReconciliationPending) Assert.True(booking.MarkPaymentNeedsManualReview().IsSuccess);
            }
            await bookings.SaveChangesAsync(ct); await tx.CommitAsync(ct);
            message.MarkProcessed(DateTimeOffset.UtcNow); await payments.SaveChangesAsync(ct);
        }
        public Task<int> DispatchPendingAsync(int batchSize = 20, CancellationToken ct = default) => Task.FromResult(0);
    }

    private sealed class HeaderAuth(IOptionsMonitor<AuthenticationSchemeOptions> options,
        ILoggerFactory logger, UrlEncoder encoder) : AuthenticationHandler<AuthenticationSchemeOptions>(options, logger, encoder)
    {
        protected override Task<AuthenticateResult> HandleAuthenticateAsync()
        {
            if (!Guid.TryParse(Request.Headers["x-test-user"], out var id)) return Task.FromResult(AuthenticateResult.NoResult());
            var identity = new ClaimsIdentity(new[] { new Claim(ClaimTypes.NameIdentifier, id.ToString()) }, Scheme.Name);
            return Task.FromResult(AuthenticateResult.Success(new(new ClaimsPrincipal(identity), Scheme.Name)));
        }
    }
    private sealed class RequestUser(Microsoft.AspNetCore.Http.IHttpContextAccessor http) : ICurrentUser
    {
        public Guid? UserId => Guid.TryParse(http.HttpContext?.User.FindFirstValue(ClaimTypes.NameIdentifier), out var id) ? id : null;
        public IReadOnlyCollection<string> Roles => Array.Empty<string>();
        public bool IsInRole(string role) => false;
    }
}
