using System.Security.Cryptography;
using System.Text;
using CareSitter.Contracts.Services;
using CareSitter.Modules.Catalog;
using CareSitter.Modules.Catalog.Application;
using CareSitter.Modules.Catalog.Domain;
using CareSitter.Modules.Catalog.Infrastructure;
using CareSitter.SharedKernel.Results;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Npgsql;

namespace CareSitter.IntegrationTests;

[Trait("Category", "PostgreSQL")]
public sealed class BookingReportsPostgresTests : IAsyncLifetime
{
    private PostgresRaceTestDatabase database = null!;
    private static readonly byte[] Pdf = Encoding.ASCII.GetBytes("%PDF-1.7\nsynthetic report\n%%EOF\n");
    public async Task InitializeAsync() => database = await PostgresRaceTestDatabase.CreateAsync();
    public async Task DisposeAsync() { if (database is not null) await database.DisposeAsync(); }
    private ServiceProvider Services(Actor actor, Gateway gateway, FirebaseGateway? firebase = null)
    {
        var services = new ServiceCollection();
        var configuration = new ConfigurationBuilder().AddInMemoryCollection(new Dictionary<string, string?> {
            ["ConnectionStrings:CareSitter"] = database.ConnectionString }).Build();
        new CatalogModule().RegisterServices(services, configuration);
        services.UseFixtureProvider<CatalogDbContext>();
        services.AddSingleton<ICurrentUser>(actor);
        services.AddSingleton<IReportDocumentGateway>(gateway);
        if (firebase is not null) services.AddSingleton<IFirebaseReportStorage>(firebase);
        services.AddSingleton<IClock>(new Clock());
        services.AddSingleton<IBookingReportAccess>(actor);
        services.AddLogging();
        return services.BuildServiceProvider();
    }
    private async Task<(Guid Booking, Guid Owner)> Seed()
    {
        await using var conn = await database.OpenConnectionAsync();
        await using var cmd = new NpgsqlCommand("""
            INSERT INTO booking.bookings (customer_id, beneficiary_id, address_id, service_type_id,
                scheduled_start, scheduled_end, status)
            SELECT b.customer_id, b.id, a.id, s.id, now() + interval '3 days', now() + interval '3 days 2 hours', 'DRAFT'
            FROM people.beneficiaries b JOIN catalog.addresses a ON a.owner_user_id=b.customer_id
            CROSS JOIN LATERAL (SELECT id FROM catalog.service_types ORDER BY id LIMIT 1) s
            ORDER BY b.id, a.id LIMIT 1 RETURNING id, customer_id;
            """, conn);
        await using var reader = await cmd.ExecuteReaderAsync();
        Assert.True(await reader.ReadAsync()); return (reader.GetGuid(0), reader.GetGuid(1));
    }

    [PostgresFact]
    public async Task Retry_replays_durable_receipt_and_owner_or_admin_can_read_private_pdf()
    {
        var (booking, owner) = await Seed();
        var actor = new Actor(owner, booking); var gateway = new Gateway();
        using var services = Services(actor, gateway);
        var key = Guid.NewGuid(); Guid id;
        using (var scope = services.CreateScope())
        {
            var result = await scope.ServiceProvider.GetRequiredService<ReportService>().UploadAsync(booking, key, Pdf, default);
            Assert.True(result.IsSuccess, result.Error.Message); id = result.Value.Id;
        }
        using (var scope = services.CreateScope())
        {
            var service = scope.ServiceProvider.GetRequiredService<ReportService>();
            var replay = await service.UploadAsync(booking, key, Pdf, default);
            Assert.True(replay.IsSuccess); Assert.Equal(id, replay.Value.Id); Assert.Equal(1, gateway.Uploads);
            Assert.True((await service.ReadAsync(id, default)).IsSuccess);
            var db = scope.ServiceProvider.GetRequiredService<CatalogDbContext>();
            var asset = await db.MediaAssets.SingleAsync(x => x.Id == id);
            Assert.True(asset.IsSensitive); Assert.Null(asset.Url);
            Assert.Equal("authenticated", asset.DeliveryType); Assert.Equal("pdf", asset.FileFormat);
            var json = System.Text.Json.JsonSerializer.Serialize(replay.Value);
            Assert.DoesNotContain("ObjectKey", json); Assert.DoesNotContain("CloudName", json);
            actor.Id = Guid.NewGuid();
            Assert.Equal("report.not_found", (await service.ReadAsync(id, default)).Error.Code);
            Assert.Equal(1, gateway.Downloads);
            actor.Role = "ADMIN";
            Assert.True((await service.ReadAsync(id, default)).IsSuccess);
        }
    }

    [PostgresFact]
    public async Task Concurrent_same_key_claims_once_and_changed_payload_is_rejected()
    {
        var (booking, owner) = await Seed(); var actor = new Actor(owner, booking);
        var gateway = new Gateway { Pending = new(TaskCreationOptions.RunContinuationsAsynchronously) };
        using var services = Services(actor, gateway);
        var key = Guid.NewGuid();
        using var first = services.CreateScope(); using var second = services.CreateScope();
        var uploading = first.ServiceProvider.GetRequiredService<ReportService>().UploadAsync(booking, key, Pdf, default);
        await gateway.Started.Task.WaitAsync(TimeSpan.FromSeconds(10));
        var blocked = await second.ServiceProvider.GetRequiredService<ReportService>().UploadAsync(booking, key, Pdf, default);
        Assert.Equal("report.upload_pending", blocked.Error.Code); Assert.Equal(1, gateway.Uploads);
        gateway.Pending.SetResult(true); Assert.True((await uploading).IsSuccess);
        using var third = services.CreateScope();
        var changed = await third.ServiceProvider.GetRequiredService<ReportService>().UploadAsync(booking, key,
            Encoding.ASCII.GetBytes("%PDF-1.7\nchanged report\n%%EOF\n"), default);
        Assert.Equal("report.idempotency_conflict", changed.Error.Code); Assert.Equal(1, gateway.Uploads);
    }

    [PostgresFact]
    public async Task Expired_lease_reuses_object_key_and_fences_stale_completion()
    {
        var (booking, owner) = await Seed(); var actor = new Actor(owner, booking);
        using var services = Services(actor, new Gateway());
        var now = DateTimeOffset.UtcNow; var key = Guid.NewGuid();
        var checksum = Convert.ToHexString(SHA256.HashData(Pdf)).ToLowerInvariant();
        using var first = services.CreateScope(); using var second = services.CreateScope();
        var oldStore = first.ServiceProvider.GetRequiredService<IReportUploadStore>();
        var newStore = second.ServiceProvider.GetRequiredService<IReportUploadStore>();
        var old = (await oldStore.ReserveAsync(owner, booking, key, checksum, Pdf.Length, "test-cloud", now, default)).Value;
        var retry = (await newStore.ReserveAsync(owner, booking, key, checksum, Pdf.Length, "test-cloud", now.AddSeconds(91), default)).Value;
        Assert.Equal(old.ObjectKey, retry.ObjectKey); Assert.NotEqual(old.LeaseToken, retry.LeaseToken);
        Assert.False(await oldStore.CompleteAsync(old, default));
        Assert.True(await newStore.CompleteAsync(retry, default));
        Assert.Equal("COMPLETED", (await newStore.FindAsync(retry.Id, default))!.Status);
    }

    [PostgresFact]
    public async Task Invalid_pdf_or_wrong_customer_never_reaches_provider()
    {
        var (booking, owner) = await Seed(); var actor = new Actor(owner, booking); var gateway = new Gateway();
        using var services = Services(actor, gateway); using var scope = services.CreateScope();
        var service = scope.ServiceProvider.GetRequiredService<ReportService>();
        Assert.Equal("report.invalid_pdf", (await service.UploadAsync(booking, Guid.NewGuid(), "not pdf"u8.ToArray(), default)).Error.Code);
        actor.Id = Guid.NewGuid();
        Assert.Equal("report.booking_not_found", (await service.UploadAsync(booking, Guid.NewGuid(), Pdf, default)).Error.Code);
        Assert.Equal(0, gateway.Uploads);
    }

    [PostgresFact]
    public async Task Firebase_intent_retry_is_immediate_immutable_and_completion_is_idempotent()
    {
        var (booking, owner) = await Seed();
        var actor = new Actor(owner, booking); var firebase = new FirebaseGateway();
        using var services = Services(actor, new Gateway(), firebase);
        var request = new PrepareFirebaseReport(Guid.NewGuid(), Pdf.Length,
            Convert.ToHexString(SHA256.HashData(Pdf)).ToLowerInvariant());
        Guid id;
        using (var scope = services.CreateScope())
        {
            var service = scope.ServiceProvider.GetRequiredService<FirebaseReportService>();
            var prepared = await service.PrepareAsync(booking, request, DateTimeOffset.UtcNow.AddHours(1).ToUnixTimeMilliseconds(), default);
            Assert.True(prepared.IsSuccess, prepared.Error.Message);
            id = prepared.Value.Report.Id;
            Assert.Equal($"reports/{owner:D}/{id:N}.pdf", prepared.Value.ObjectPath);
            Assert.Equal(owner.ToString("D"), prepared.Value.Uid);
            Assert.InRange(prepared.Value.ExpiresAtMs, DateTimeOffset.UtcNow.ToUnixTimeMilliseconds(),
                DateTimeOffset.UtcNow.AddMinutes(5).ToUnixTimeMilliseconds());
            var retry = await service.PrepareAsync(booking, request, prepared.Value.ExpiresAtMs, default);
            Assert.True(retry.IsSuccess); Assert.Equal(id, retry.Value.Report.Id);
            Assert.Equal("report.upload_pending", (await service.CompleteAsync(id, default)).Error.Code);
        }
        firebase.Bytes = Pdf;
        using (var scope = services.CreateScope())
        {
            var service = scope.ServiceProvider.GetRequiredService<FirebaseReportService>();
            Assert.True((await service.CompleteAsync(id, default)).IsSuccess);
            Assert.True((await service.CompleteAsync(id, default)).IsSuccess);
            var replay = await service.PrepareAsync(booking, request, DateTimeOffset.UtcNow.AddMinutes(5).ToUnixTimeMilliseconds(), default);
            Assert.True(replay.Value.Report.Status == "COMPLETED"); Assert.Null(replay.Value.CustomToken);
            var db = scope.ServiceProvider.GetRequiredService<CatalogDbContext>();
            var asset = await db.MediaAssets.SingleAsync(x => x.Id == id);
            Assert.Equal("FIREBASE", asset.StorageProvider); Assert.Equal("private", asset.DeliveryType);
            Assert.Null(asset.Url); Assert.True(asset.IsSensitive);
            Assert.Equal(1, await db.MediaAssets.CountAsync(x => x.Id == id));
        }
    }

    [PostgresFact]
    public async Task Firebase_wrong_owner_payload_and_file_never_publish_success()
    {
        var (booking, owner) = await Seed();
        var actor = new Actor(owner, booking); var firebase = new FirebaseGateway();
        using var services = Services(actor, new Gateway(), firebase); using var scope = services.CreateScope();
        var service = scope.ServiceProvider.GetRequiredService<FirebaseReportService>();
        var request = new PrepareFirebaseReport(Guid.NewGuid(), Pdf.Length,
            Convert.ToHexString(SHA256.HashData(Pdf)).ToLowerInvariant());
        var expiry = DateTimeOffset.UtcNow.AddMinutes(5).ToUnixTimeMilliseconds();
        var prepared = (await service.PrepareAsync(booking, request, expiry, default)).Value;
        var changed = await service.PrepareAsync(booking, request with { Checksum = new string('b', 64) }, expiry, default);
        Assert.Equal("report.idempotency_conflict", changed.Error.Code);
        actor.Id = Guid.NewGuid();
        Assert.Equal("report.not_found", (await service.CompleteAsync(prepared.Report.Id, default)).Error.Code);
        Assert.Equal(0, firebase.Downloads);
        Assert.Equal("report.booking_not_found", (await service.PrepareAsync(booking, request, expiry, default)).Error.Code);
        actor.Id = owner;
        firebase.Bytes = Pdf.ToArray(); firebase.Bytes[12] ^= 1;
        Assert.Equal("report.invalid_pdf", (await service.CompleteAsync(prepared.Report.Id, default)).Error.Code);
        var db = scope.ServiceProvider.GetRequiredService<CatalogDbContext>();
        Assert.Equal("PENDING", (await db.ReportUploads.AsNoTracking().SingleAsync()).Status);
        Assert.Equal(0, await db.MediaAssets.CountAsync(x => x.Id == prepared.Report.Id));
        Assert.Equal("report.invalid_pdf", (await service.PrepareAsync(booking, request with { SizeBytes = ReportPdfPolicy.MaxBytes + 1L }, expiry, default)).Error.Code);
        Assert.Equal("auth.required", (await service.PrepareAsync(booking, request, 1, default)).Error.Code);
    }

    [PostgresFact]
    public async Task Firebase_concurrent_completions_create_only_one_private_asset()
    {
        var (booking, owner) = await Seed();
        using var services = Services(new Actor(owner, booking), new Gateway(), new FirebaseGateway { Bytes = Pdf });
        Guid id;
        using (var scope = services.CreateScope())
        {
            var service = scope.ServiceProvider.GetRequiredService<FirebaseReportService>();
            var request = new PrepareFirebaseReport(Guid.NewGuid(), Pdf.Length,
                Convert.ToHexString(SHA256.HashData(Pdf)).ToLowerInvariant());
            id = (await service.PrepareAsync(booking, request, DateTimeOffset.UtcNow.AddMinutes(5).ToUnixTimeMilliseconds(), default)).Value.Report.Id;
        }
        using var first = services.CreateScope(); using var second = services.CreateScope();
        var results = await Task.WhenAll(
            first.ServiceProvider.GetRequiredService<FirebaseReportService>().CompleteAsync(id, default),
            second.ServiceProvider.GetRequiredService<FirebaseReportService>().CompleteAsync(id, default));
        Assert.All(results, result => Assert.True(result.IsSuccess, result.Error.Message));
        var db = first.ServiceProvider.GetRequiredService<CatalogDbContext>();
        Assert.Equal(1, await db.MediaAssets.CountAsync(x => x.Id == id));
    }

    private sealed class FirebaseGateway : IFirebaseReportStorage
    {
        public string Bucket => "demo-caresitter.firebasestorage.app";
        public string ProjectId => "demo-caresitter";
        public byte[]? Bytes; public int Downloads;
        public Task<Result<string>> CreateTokenAsync(ReportUpload report, long expiresAtMs, CancellationToken ct) =>
            Task.FromResult<Result<string>>("synthetic-token");
        public Task<Result<byte[]>> DownloadAsync(ReportUpload report, CancellationToken ct)
        {
            Downloads++;
            return Task.FromResult<Result<byte[]>>(Bytes is not null ? Bytes : Error.Conflict("report.upload_pending", "Pending"));
        }
    }

    private sealed class Actor(Guid owner, Guid booking) : ICurrentUser, IBookingReportAccess
    {
        private readonly Guid _owner = owner;
        public Guid Id { get; set; } = owner; public string Role = "CUSTOMER";
        public Guid? UserId => Id; public IReadOnlyCollection<string> Roles => [Role];
        public bool IsInRole(string role) => Role == role;
        public Task<bool> IsCustomerAsync(Guid b, Guid user, CancellationToken ct = default) => Task.FromResult(b == booking && user == _owner);
    }
    private sealed class Clock : IClock { public DateTimeOffset UtcNow => DateTimeOffset.UtcNow; }
    private sealed class Gateway : IReportDocumentGateway
    {
        public string CloudName => "test-cloud"; public int Uploads, Downloads;
        public TaskCompletionSource<bool>? Pending;
        public TaskCompletionSource<bool> Started = new(TaskCreationOptions.RunContinuationsAsynchronously);
        public async Task<Result<bool>> UploadAsync(ReportUpload report, byte[] bytes, CancellationToken ct)
        { Interlocked.Increment(ref Uploads); Started.TrySetResult(true); if (Pending != null) await Pending.Task; return true; }
        public Task<Result<byte[]>> DownloadAsync(ReportUpload report, CancellationToken ct)
        { Downloads++; return Task.FromResult<Result<byte[]>>(Pdf); }
    }
}
