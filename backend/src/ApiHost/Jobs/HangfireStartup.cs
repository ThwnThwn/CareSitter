using CareSitter.ApiHost.ChatFirestore;
using CareSitter.ApiHost.Security;
using CareSitter.Contracts.Services;
using CareSitter.Modules.Booking;
using Hangfire;
using Hangfire.Common;
using Hangfire.InMemory;
using Hangfire.PostgreSql;
using Npgsql;

namespace CareSitter.ApiHost.Jobs;

internal sealed class HangfireStartup
{
    private readonly string? _postgresConnectionString;

    private HangfireStartup(string? postgresConnectionString)
    {
        _postgresConnectionString = postgresConnectionString;
    }

    public static HangfireStartup Configure(WebApplicationBuilder builder)
    {
        // Production must use shared PostgreSQL storage so jobs survive restarts and
        // multiple API instances coordinate through Hangfire's distributed locks.
        var usePostgresHangfire = DeploymentConfiguration.UsePostgresHangfire(
            builder.Configuration,
            builder.Environment.IsProduction());
        var hangfireConnectionString = builder.Configuration.GetConnectionString("CareSitter");

        builder.Services.AddHangfire(config =>
        {
            config.SetDataCompatibilityLevel(CompatibilityLevel.Version_180)
                  .UseSimpleAssemblyNameTypeSerializer()
                  .UseRecommendedSerializerSettings();

            if (usePostgresHangfire)
            {
                config.UsePostgreSqlStorage(options => options.UseNpgsqlConnection(hangfireConnectionString!));
            }
            else
            {
                // InMemory: jobs mất khi restart — chấp nhận được cho development.
                config.UseInMemoryStorage();
            }
        });
        builder.Services.AddHangfireServer(options =>
        {
            options.ServerName = $"{Environment.MachineName}:{Guid.NewGuid():N}";
            options.WorkerCount = 2;
            options.Queues = new[] { "default", "booking" };
        });

        return new HangfireStartup(usePostgresHangfire ? hangfireConnectionString : null);
    }

    public async Task VerifyStorageAsync()
    {
        if (_postgresConnectionString is null)
            return;

        // Fail before accepting requests if persistent job storage is unreachable.
        try
        {
            await using var connection = new NpgsqlConnection(_postgresConnectionString);
            await connection.OpenAsync();
            await using var command = new NpgsqlCommand("SELECT 1", connection);
            await command.ExecuteScalarAsync();
        }
        catch (Exception ex)
        {
            throw new InvalidOperationException(
                "Hangfire PostgreSQL storage is unavailable; refusing to start the API.", ex);
        }
    }

    public static void UseDashboardAndScheduleJobs(WebApplication app)
    {
        // Dev: localhost-only (không cần JWT).
        // Prod: yêu cầu JWT với role ADMIN — ops xem job qua /hangfire sau khi login admin.
        app.UseHangfireDashboard("/hangfire", new DashboardOptions
        {
            DashboardTitle = "CareSitter — Hangfire Jobs",
            Authorization = new[]
            {
                new HangfireDashboardAuthFilter(app.Environment)
            },
            // Chỉ cho phép xem, không cho trigger/delete job từ Dashboard trong Production
            IsReadOnlyFunc = ctx => !app.Environment.IsDevelopment(),
        });

        // Every instance writes the same stable recurring IDs into the shared PostgreSQL
        // store; Hangfire's distributed lock prevents duplicate scheduling across servers.
        RecurringJob.RemoveIfExists("expire-pending-payments");
        if (app.Configuration.GetValue<bool>("ChatFirestore:ProjectionEnabled") &&
            app.Configuration.GetValue("ChatFirestore:ReconcileEnabled", true))
            RecurringJob.AddOrUpdate<ChatFirestoreReconcileJob>(
                recurringJobId: "reconcile-chat-firestore",
                methodCall: job => job.RunAsync(CancellationToken.None),
                cronExpression: "*/15 * * * *", queue: "default");
        else
            RecurringJob.RemoveIfExists("reconcile-chat-firestore");
        var cleanupMethod = BookingModule.LiveLocationCleanupMethod;
        var cleanupJob = new Job(cleanupMethod.DeclaringType!, cleanupMethod, [CancellationToken.None], "booking");
        app.Services.GetRequiredService<IRecurringJobManager>().AddOrUpdate(
            "cleanup-live-locations", cleanupJob, "*/5 * * * *", new RecurringJobOptions());
        RecurringJob.AddOrUpdate<IBookingJobsService>(
            recurringJobId: "reconcile-pending-payments",
            methodCall: svc => svc.ReconcilePendingPaymentsAsync(),
            cronExpression: "* * * * *",   // Mỗi 1 phút
            queue: "booking");

        RecurringJob.AddOrUpdate<IBookingJobsService>(
            recurringJobId: "alert-late-checkins",
            methodCall: svc => svc.AlertLateCheckinsAsync(),
            cronExpression: "*/5 * * * *", // Mỗi 5 phút
            queue: "booking");

        RecurringJob.AddOrUpdate<IBookingJobsService>(
            recurringJobId: "auto-request-checkout-expired-shifts",
            methodCall: svc => svc.AutoRequestCheckoutExpiredShiftsAsync(),
            cronExpression: "*/5 * * * *", // Mỗi 5 phút
            queue: "booking");

        RecurringJob.AddOrUpdate<IBookingJobsService>(
            recurringJobId: "auto-confirm-pending-checkouts",
            methodCall: svc => svc.AutoConfirmPendingCheckoutsAsync(),
            cronExpression: "*/15 * * * *", // Mỗi 15 phút
            queue: "booking");

        RecurringJob.AddOrUpdate<IBookingJobsService>(
            recurringJobId: "expand-expired-booking-offers",
            methodCall: svc => svc.ExpandExpiredBookingOffersAsync(),
            cronExpression: "* * * * *", // Mỗi 1 phút
            queue: "booking");

        RecurringJob.AddOrUpdate<IBookingJobsService>(
            recurringJobId: "refund-unmatched-bookings",
            methodCall: svc => svc.RefundUnmatchedBookingsAsync(),
            cronExpression: "* * * * *", // Retry nhanh, refund idempotent
            queue: "booking");

        RecurringJob.AddOrUpdate<IBookingJobsService>(
            recurringJobId: "release-mature-settlements",
            methodCall: svc => svc.ReleaseMatureSettlementsAsync(),
            cronExpression: "*/5 * * * *", // Mỗi 5 phút, idempotent theo booking
            queue: "booking");
    }
}
