using CareSitter.Contracts.Services;
using CareSitter.Infrastructure.Hubs;
using CareSitter.Modules.Booking.Application;
using CareSitter.Modules.Booking.Application.Sync;
using CareSitter.Modules.Booking.Application.BookingChat;
using CareSitter.Modules.Booking.Application.Commands.CreateBooking;
using CareSitter.Modules.Booking.Domain;
using CareSitter.Modules.Booking.Infrastructure;
using CareSitter.SharedKernel.Modules;
using Microsoft.AspNetCore.Routing;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Options;
using FluentValidation;
using Microsoft.AspNetCore.DataProtection;
using System.Reflection;

namespace CareSitter.Modules.Booking;

public sealed class BookingModule : IModule
{
    public string Name => "Booking";

    /// <summary>
    /// Chạy backfill có kiểm soát cho các booking cũ, thông qua store nội bộ của module.
    /// Caller tạo scope và chỉ gọi khi chủ động chạy tác vụ bảo trì.
    /// </summary>
    public static async Task<(BookingChatBackfillResult Result, int Remaining)>
        BackfillMissingChatConversationsAsync(IServiceProvider services, int batchSize,
            CancellationToken ct = default)
    {
        if (!services.GetRequiredService<IOptions<BookingChatOptions>>().Value.Enabled)
            throw new InvalidOperationException("Booking chat must be enabled before backfill.");
        var store = services.GetRequiredService<IBookingChatBackfillStore>();
        var result = await store.BackfillMissingConversationsAsync(batchSize, ct);
        var remaining = await store.CountMissingConversationsAsync(ct);
        return (result, remaining);
    }

    public void RegisterServices(IServiceCollection services, IConfiguration configuration)
    {
        services.AddOptions<MatchingOptions>()
            .Bind(configuration.GetSection(MatchingOptions.SectionName))
            .Validate(options => options.InitialOfferCount > 0 && options.ExpansionOfferCount > 0,
                "Matching offer counts must be positive.")
            .Validate(options => options.MaxDistanceMeters > 0 && options.RouteCandidateLimit > 0,
                "Matching distance and route candidate limit must be positive.")
            .ValidateOnStart();
        services.AddOptions<CheckInOptions>()
            .Bind(configuration.GetSection(CheckInOptions.SectionName))
            .Validate(options => options.EarlyWindowMinutes is >= 0 and <= 180,
                "CheckIn:EarlyWindowMinutes phai nam trong khoang 0-180.")
            .Validate(options => options.MaxDistanceMeters is >= 10 and <= 1_000,
                "CheckIn:MaxDistanceMeters phai nam trong khoang 10-1000.")
            .ValidateOnStart();
        services.AddOptions<BookingPaymentOptions>()
            .Bind(configuration.GetSection(BookingPaymentOptions.SectionName));
        // ASP.NET ánh xạ LiveTracking__* trong .env/biến môi trường vào section này.
        // Không đặt cấu hình tracking trong appsettings; giá trị mặc định tắt tính năng.
        services.AddOptions<LiveTrackingOptions>()
            .Bind(configuration.GetSection(LiveTrackingOptions.SectionName))
            .Validate(x => x.SendIntervalSeconds is >= 10 and <= 15 &&
                x.LeaseSeconds is >= 60 and <= 600 && x.RetentionHours is >= 1 and <= 48 &&
                x.MaxSampleAgeSeconds is >= 30 and <= 120 && x.MaxFutureSkewSeconds is >= 0 and <= 30,
                "LiveTracking configuration is outside the supported range.")
            .ValidateOnStart();
        services.AddOptions<BookingChatOptions>()
            .Bind(configuration.GetSection(BookingChatOptions.SectionName))
            .Validate(x => x.PostShiftGraceHours is >= 1 and <= 168,
                "BookingChat:PostShiftGraceHours phai nam trong khoang 1-168.")
            .Validate(x => x.RetentionDays is >= 30 and <= 730,
                "BookingChat:RetentionDays phai nam trong khoang 30-730.")
            .Validate(x => x.DispatcherPollIntervalSeconds is >= 1 and <= 300,
                "BookingChat:DispatcherPollIntervalSeconds phai nam trong khoang 1-300.")
            .Validate(x => x.DispatcherLeaseSeconds is >= 5 and <= 600,
                "BookingChat:DispatcherLeaseSeconds phai nam trong khoang 5-600.")
            .Validate(x => x.DispatcherBatchSize is >= 1 and <= 200,
                "BookingChat:DispatcherBatchSize phai nam trong khoang 1-200.")
            .Validate(x => x.DispatcherMaxAttempts is >= 1 and <= 50,
                "BookingChat:DispatcherMaxAttempts phai nam trong khoang 1-50.")
            .Validate(x => x.DispatcherRetryDelaySeconds is >= 1 and <= 3600,
                "BookingChat:DispatcherRetryDelaySeconds phai nam trong khoang 1-3600.")
            .Validate(x => x.RetentionPollIntervalMinutes is >= 5 and <= 1_440,
                "BookingChat:RetentionPollIntervalMinutes phai nam trong khoang 5-1440.")
            .ValidateOnStart();
        services.AddOptions<BookingSideEffectOptions>()
            .Bind(configuration.GetSection(BookingSideEffectOptions.SectionName))
            .Validate(x => x.PollIntervalSeconds is >= 1 and <= 300 &&
                x.LeaseSeconds is >= 5 and <= 600 &&
                x.BatchSize is >= 1 and <= 200 &&
                x.MaxAttempts is >= 1 and <= 50 &&
                x.RetryDelaySeconds is >= 1 and <= 3600,
                "BookingSideEffects configuration is outside the supported range.")
            .ValidateOnStart();

        services.AddDbContext<BookingDbContext>(options =>
            options.UseNpgsql(
                configuration.GetConnectionString("CareSitter"),
                npgsql => npgsql.UseNetTopologySuite()
                    .MigrationsHistoryTable("__ef_migrations", BookingDbContext.SchemaName)));
        services.AddDataProtection();

        services.AddMediatR(cfg => cfg.RegisterServicesFromAssemblyContaining<BookingModule>());
        services.AddValidatorsFromAssemblyContaining<BookingModule>();

        // Đăng ký Controllers nằm trong assembly của Booking module
        services.AddControllers()
            .AddApplicationPart(Assembly.GetAssembly(typeof(BookingModule))!);

        // Đăng ký BookingMembershipReader để CareTrackingHub verify quyền join SignalR group.
        // Hub resolve IBookingMembershipChecker (Shared interface) → implementation nằm ở đây.
        // Scoped vì phụ thuộc BookingDbContext (cũng Scoped).
        services.AddScoped<IBookingMembershipChecker, BookingMembershipReader>();
        services.AddScoped<IBookingPartyAccess, BookingMembershipReader>();
        services.AddScoped<IReviewBookingLookup, ReviewBookingLookup>();
        services.AddScoped<IDisputeBookingWorkflow, DisputeBookingWorkflow>();

        // BookingSyncService: ghi sync event và query delta.
        // Scoped vì inject BookingDbContext (Scoped).
        services.AddScoped<IBookingSyncService, BookingSyncService>();
        services.AddScoped<IBookingRepository, BookingRepository>();
        services.AddScoped<IBookingCreationIdempotencyStore, BookingCreationIdempotencyStore>();
        services.AddScoped<IBookingResponseMapper, BookingResponseMapper>();
        services.AddScoped<IBookingPostCommitService, BookingPostCommitService>();
        services.AddScoped<BookingDomainOutboxDispatcher>();
        services.AddScoped<IBookingAcceptanceTransaction, BookingAcceptanceTransaction>();
        services.AddScoped<IBookingChatWriter, BookingChatWriter>();
        services.AddScoped<IBookingChatService, BookingChatService>();
        services.AddScoped<IBookingChatAdminService, BookingChatAdminService>();
        services.AddScoped<IBookingChatDispatcher, BookingChatDispatcher>();
        services.AddScoped<BookingChatReportDispatcher>();
        services.AddScoped<BookingChatRetentionService>();
        services.AddScoped<IBookingChatBackfillStore, BookingChatBackfillStore>();
        services.AddSingleton<BookingChatMetrics>();
        // Worker tự tắt khi BookingChat:Enabled=false; outbox đã commit vẫn được giữ
        // và sẽ gửi tiếp khi bật lại, không mất signal.
        services.AddHostedService<BookingChatDispatchWorker>();
        services.AddHostedService<BookingDomainOutboxWorker>();
        services.AddHostedService<BookingChatReportWorker>();
        services.AddHostedService<BookingChatRetentionWorker>();
        services.AddScoped<IChecklistTemplateManager, ChecklistTemplateManager>();
        services.AddScoped<IServiceChecklistReader, ServiceChecklistReader>();
        services.AddScoped<IBookingTrackingStore, BookingTrackingStore>();
        services.AddScoped<IBookingTrackingNotifier, BookingTrackingNotifier>();
        services.AddScoped<ILiveLocationStore, LiveLocationStore>();
        services.AddScoped(sp => new LiveLocationCleanupJob(sp.GetRequiredService<ILiveLocationStore>()));
        services.AddScoped<ICareTaskManager, CareTaskManager>();
        services.AddScoped<IBookingReadStore, BookingReadStore>();
        services.AddScoped<IBookingPaymentGateway, BookingPaymentGateway>();
        services.AddScoped<IMatchingService, MatchingService>();
        services.AddScoped<IBookingJobsService, BookingJobsService>();
        services.AddScoped<IBookingCheckoutStore, BookingCheckoutStore>();
        services.AddScoped<BookingCheckoutJobs>();
        services.AddScoped<IBookingSettlementStore, BookingSettlementStore>();
        services.AddScoped<IBookingJobNotifier, BookingJobNotifier>();
        services.AddScoped<IAdminBookingReader, AdminBookingReader>();
        services.AddScoped<IPromotionBookingLookup, PromotionBookingLookup>();
    }

    // Controllers tự được map qua app.MapControllers() ở Program.cs
    public void MapEndpoints(IEndpointRouteBuilder endpoints) { }
}

