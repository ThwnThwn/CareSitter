using CareSitter.Contracts.Services;
using CareSitter.Modules.Payments.Application;
using CareSitter.Modules.Payments.Application.Refunds;
using CareSitter.Modules.Payments.Application.Payouts;
using CareSitter.Modules.Payments.Application.Payouts.ApprovePayout;
using CareSitter.Modules.Payments.Application.Payouts.CreatePayout;
using CareSitter.Modules.Payments.Application.Payouts.ListMyPayouts;
using CareSitter.Modules.Payments.Application.Payouts.ListPendingPayouts;
using CareSitter.Modules.Payments.Application.Payouts.RejectPayout;
using CareSitter.Modules.Payments.Infrastructure;
using CareSitter.SharedKernel.Modules;
using CareSitter.SharedKernel.Results;
using FluentValidation;
using MediatR;
using Microsoft.AspNetCore.Routing;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using System.Reflection;
using CareSitter.Messaging.Persistence;

namespace CareSitter.Modules.Payments;

public sealed class PaymentsModule : IModule
{
    public string Name => "Payments";

    public void RegisterServices(IServiceCollection services, IConfiguration configuration)
    {
        services.AddDbContext<PaymentsDbContext>(options =>
            options.UseNpgsql(
                configuration.GetConnectionString("CareSitter"),
                npgsql => npgsql.UseNetTopologySuite()
                    .MigrationsHistoryTable("__ef_migrations", PaymentsDbContext.SchemaName)));

        services.AddMediatR(cfg =>
            cfg.RegisterServicesFromAssemblyContaining<PaymentsModule>());
        services.AddValidatorsFromAssemblyContaining<PaymentsModule>();
        services.AddTransient<
            IPipelineBehavior<CreatePayoutCommand, Result<CreatePayoutResult>>,
            PayoutValidationBehavior<CreatePayoutCommand, CreatePayoutResult>>();
        services.AddTransient<
            IPipelineBehavior<ListMyPayoutsQuery, Result<PayoutPage>>,
            PayoutValidationBehavior<ListMyPayoutsQuery, PayoutPage>>();
        services.AddTransient<
            IPipelineBehavior<ListPendingPayoutsQuery, Result<PayoutPage>>,
            PayoutValidationBehavior<ListPendingPayoutsQuery, PayoutPage>>();
        services.AddTransient<
            IPipelineBehavior<ApprovePayoutCommand, Result<PayoutResponse>>,
            PayoutValidationBehavior<ApprovePayoutCommand, PayoutResponse>>();
        services.AddTransient<
            IPipelineBehavior<RejectPayoutCommand, Result<PayoutResponse>>,
            PayoutValidationBehavior<RejectPayoutCommand, PayoutResponse>>();
        services.AddScoped<PayoutMapper>();
        services.AddScoped<IPayoutStore, PayoutStore>();
        services.AddScoped<IPayoutProcessor, PayoutProcessor>();
        services.AddScoped<IRefundStore, RefundStore>();
        services.AddScoped<IOriginalPaymentRefundCoordinator, OriginalPaymentRefundCoordinator>();
        services.AddScoped<IRefundProcessor, RefundProcessor>();
        services.AddScoped<IWalletLedgerStore, WalletLedgerStore>();
        services.AddScoped<IWalletService, WalletService>();
        services.AddOptions<VNPayOptions>()
            .Bind(configuration.GetSection(VNPayOptions.SectionName))
            .Validate(options => options.PaymentTimeoutMinutes is >= 5 and <= 60,
                "Payments:VNPay:PaymentTimeoutMinutes phai nam trong khoang 5-60.")
            .Validate(options => options.BookingPaymentDeadlineMinutes is >= 5 and <= 180,
                "Payments:VNPay:BookingPaymentDeadlineMinutes phai nam trong khoang 5-180.")
            .Validate(options => options.BookingPaymentDeadlineMinutes >= options.PaymentTimeoutMinutes,
                "BookingPaymentDeadlineMinutes phai lon hon hoac bang PaymentTimeoutMinutes.")
            .Validate(options => options.MaxReconciliationAttempts is >= 1 and <= 10,
                "Payments:VNPay:MaxReconciliationAttempts phai nam trong khoang 1-10.")
            .Validate(options => options.ReconciliationWindowMinutes is >= 1 and <= 60,
                "Payments:VNPay:ReconciliationWindowMinutes phai nam trong khoang 1-60.")
            .ValidateOnStart();
        services.AddHttpClient<IVNPayService, VNPayService>(client =>
            client.Timeout = TimeSpan.FromSeconds(10));
        services.AddOptions<VNPayRefundOptions>()
            .Bind(configuration.GetSection(VNPayRefundOptions.SectionName))
            .Validate(options => !options.Enabled || VNPayRefundGateway.IsValidEndpoint(options.ApiUrl),
                "Enabled VNPAY refunds require an explicit HTTPS API endpoint.")
            .Validate(VNPayRefundOptions.HasValidWorkerSettings,
                "Payments:VNPayRefund worker/IP settings are invalid.")
            .ValidateOnStart();
        // No redirect or retry handler: a second POST can move money a second time.
        services.AddHttpClient<IVNPayRefundGateway, VNPayRefundGateway>(client =>
            client.Timeout = TimeSpan.FromSeconds(10))
            .ConfigurePrimaryHttpMessageHandler(() => new HttpClientHandler { AllowAutoRedirect = false });
        services.AddScoped<IPaymentFinalizationService, PaymentFinalizationService>();
        services.AddOptions<PayOSOptions>().Bind(configuration.GetSection(PayOSOptions.SectionName))
            .Validate(PayOSOptions.IsValid, "payOS bật cần đủ ClientId, ApiKey, ChecksumKey và URL HTTPS.")
            .ValidateOnStart();
        services.AddHttpClient<IPayOSService, PayOSService>(client => client.Timeout = TimeSpan.FromSeconds(10))
            .ConfigurePrimaryHttpMessageHandler(() => new HttpClientHandler { AllowAutoRedirect = false });
        services.AddScoped<IPayOSPaymentPortal, PayOSPaymentPortal>();
        services.AddOptions<PayOSPayoutOptions>()
            .Bind(configuration.GetSection(PayOSPayoutOptions.SectionName))
            .Validate(PayOSPayoutOptions.IsValid,
                "payOS Payout bật cần đủ bộ ClientId, ApiKey, ChecksumKey riêng và polling hợp lệ.")
            .ValidateOnStart();
        // The official SDK signs requests, validates signed responses and retries create
        // with the same provider idempotency key.
        services.AddHttpClient<IPayoutProvider, PayOSPayoutProvider>(client =>
                client.Timeout = TimeSpan.FromSeconds(10))
            .ConfigurePrimaryHttpMessageHandler(() => new HttpClientHandler
            {
                AllowAutoRedirect = false
            });
        services.AddScoped<IPaymentStatusGateway, PaymentStatusGateway>();
        services.AddModuleOutbox<PaymentsDbContext>(configuration, PaymentsDbContext.SchemaName,
            string.Equals(configuration["KAFKA_ENABLED"], "true", StringComparison.OrdinalIgnoreCase));
        services.AddScoped<IPaymentWebhookProcessor, PaymentWebhookProcessor>();
        services.AddScoped<IVnPayCallbackProcessor, VNPayCallbackProcessor>();
        services.AddScoped<IPaymentReconciliationProcessor, PaymentReconciliationProcessor>();
        services.AddScoped<IPaymentReconciliationJob, PaymentReconciliationJob>();
        services.AddScoped<IPaymentPortal, PaymentPortal>();
        services.AddScoped<IPaymentOutboxDispatcher, PaymentOutboxDispatcher>();
        services.AddScoped<IAdminPaymentsReader, AdminPaymentsReader>();
        services.AddHostedService<PaymentOutboxWorker>();
        services.AddHostedService<PayoutWorker>();
        services.AddHostedService<RefundWorker>();

        // Đăng ký Controllers nằm trong assembly của Payments module
        services.AddControllers()
            .AddApplicationPart(Assembly.GetAssembly(typeof(PaymentsModule))!);
    }

    // Controllers tự được map qua app.MapControllers() ở Program.cs
    public void MapEndpoints(IEndpointRouteBuilder endpoints) { }
}
