using CareSitter.Contracts.Services;
using CareSitter.Modules.Payments.Application;
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
        services.AddScoped<IPaymentFinalizationService, PaymentFinalizationService>();
        services.AddScoped<IPaymentWebhookProcessor, PaymentWebhookProcessor>();
        services.AddScoped<IVnPayCallbackProcessor, VNPayCallbackProcessor>();
        services.AddScoped<IPaymentReconciliationProcessor, PaymentReconciliationProcessor>();
        services.AddScoped<IPaymentPortal, PaymentPortal>();

        // Đăng ký Controllers nằm trong assembly của Payments module
        services.AddControllers()
            .AddApplicationPart(Assembly.GetAssembly(typeof(PaymentsModule))!);
    }

    // Controllers tự được map qua app.MapControllers() ở Program.cs
    public void MapEndpoints(IEndpointRouteBuilder endpoints) { }
}
