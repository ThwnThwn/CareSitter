using CareSitter.Contracts.Services;
using CareSitter.Infrastructure.Hubs;
using CareSitter.Modules.Booking.Application;
using CareSitter.Modules.Booking.Application.Sync;
using CareSitter.Modules.Booking.Domain;
using CareSitter.Modules.Booking.Infrastructure;
using CareSitter.SharedKernel.Modules;
using Microsoft.AspNetCore.Routing;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using FluentValidation;
using System.Reflection;

namespace CareSitter.Modules.Booking;

public sealed class BookingModule : IModule
{
    public string Name => "Booking";

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

        services.AddDbContext<BookingDbContext>(options =>
            options.UseNpgsql(
                configuration.GetConnectionString("CareSitter"),
                npgsql => npgsql.UseNetTopologySuite()
                    .MigrationsHistoryTable("__ef_migrations", BookingDbContext.SchemaName)));

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
        services.AddScoped<IBookingResponseMapper, BookingResponseMapper>();
        services.AddScoped<IBookingPostCommitService, BookingPostCommitService>();
        services.AddScoped<IBookingAcceptanceTransaction, BookingAcceptanceTransaction>();
        services.AddScoped<IChecklistTemplateManager, ChecklistTemplateManager>();
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
