using CareSitter.Contracts.Services;
using CareSitter.Modules.Booking.Application;
using CareSitter.Modules.Booking.Application.Commands;
using CareSitter.Modules.Booking.Application.Commands.PostBookingGps;
using CareSitter.Modules.Booking.Domain;
using CareSitter.SharedKernel.Results;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Storage;
using Microsoft.Extensions.Options;
using Npgsql;

namespace CareSitter.Modules.Booking.Infrastructure;

internal sealed class LiveLocationStore(
    BookingDbContext db, ICurrentUser user, IClock clock,
    IOptionsMonitor<LiveTrackingOptions> options) : ILiveLocationStore
{
    // Luôn khóa booking trước dòng vị trí để tránh deadlock với trigger kết thúc ca.
    // Transaction cấp phiên dùng FOR UPDATE vì dòng vị trí có thể chưa tồn tại.
    public Task<Result<LiveTrackingSessionResponse>> OpenSessionAsync(
        Guid bookingId, Guid caregiverId, Guid sourceInstanceId, CancellationToken ct) =>
        GuardAsync(() => OpenSessionCoreAsync(bookingId, caregiverId, sourceInstanceId, ct));

    private async Task<Result<LiveTrackingSessionResponse>> OpenSessionCoreAsync(
        Guid bookingId, Guid caregiverId, Guid sourceInstanceId, CancellationToken ct)
    {
        await using var tx = await db.Database.BeginTransactionAsync(ct);
        var gate = await LockBookingAsync(bookingId, caregiverId, true, ct);
        if (gate.IsFailure) return gate.Error;
        var now = clock.UtcNow;
        var config = options.CurrentValue;
        var row = await LockLocationAsync(bookingId, ct);
        if (row is not null && row.ExpiresAt > now && row.SessionLeaseUntil > now &&
            row.SourceInstanceId != sourceInstanceId)
            return LiveTrackingErrors.SourceActive();

        if (row is null)
        {
            row = new LiveLocation { BookingId = bookingId, CaregiverId = caregiverId };
            db.Add(row);
        }
        if (row.TrackingSessionId == Guid.Empty || row.SourceInstanceId != sourceInstanceId ||
            row.SessionLeaseUntil <= now || row.ExpiresAt <= now)
        {
            row.TrackingSessionId = Guid.NewGuid();
            row.SourceInstanceId = sourceInstanceId;
            row.LocationVersion = await NextVersionAsync(ct);
            row.Latitude = row.Longitude = row.AccuracyMeters = row.SpeedMps = row.HeadingDegrees = null;
            row.CapturedAt = row.ReceivedAt = null;
            row.SessionLeaseUntil = now.AddSeconds(config.LeaseSeconds);
            row.ExpiresAt = now.AddHours(config.RetentionHours);
            await db.SaveChangesAsync(ct);
        }
        // Retrying session creation does not renew a live lease without a new fix.
        await tx.CommitAsync(ct);
        return new LiveTrackingSessionResponse(row.TrackingSessionId, row.LocationVersion,
            row.SessionLeaseUntil, config.SendIntervalSeconds, now);
    }

    public Task<Result<GpsTrackResponse?>> WriteAsync(
        PostBookingGpsCommand sample, Guid caregiverId, CancellationToken ct) =>
        GuardAsync(() => WriteCoreAsync(sample, caregiverId, ct));

    private async Task<Result<GpsTrackResponse?>> WriteCoreAsync(
        PostBookingGpsCommand sample, Guid caregiverId, CancellationToken ct)
    {
        // FOR SHARE chặn cập nhật trạng thái/phân công cho đến khi mẫu đã commit.
        // Nếu kết thúc ca thắng trước, kiểm tra trạng thái bên dưới sẽ từ chối GPS.
        await using var tx = await db.Database.BeginTransactionAsync(ct);
        var gate = await LockBookingAsync(sample.BookingId, caregiverId, false, ct);
        if (gate.IsFailure) return gate.Error;
        var row = await LockLocationAsync(sample.BookingId, ct);
        var now = clock.UtcNow;
        var config = options.CurrentValue;
        if (row is null || row.TrackingSessionId != sample.SessionId ||
            row.SessionLeaseUntil <= now || row.ExpiresAt <= now)
            return LiveTrackingErrors.InvalidSession();
        if (sample.CapturedAt < now.AddSeconds(-config.MaxSampleAgeSeconds) ||
            sample.CapturedAt > now.AddSeconds(config.MaxFutureSkewSeconds))
            return Error.Validation("booking.gps.invalid_time", "Thời điểm GPS đã cũ hoặc đồng hồ thiết bị không chính xác.");
        // Gói trùng hoặc đến trễ không tăng version, không gia hạn thời gian lưu.
        if (row.CapturedAt is { } captured && sample.CapturedAt <= captured)
            return Result.Success<GpsTrackResponse?>(null);
        if (row.ReceivedAt is { } received && now < received.AddSeconds(config.SendIntervalSeconds))
            return LiveTrackingErrors.TooFrequent();

        row.LocationVersion = await NextVersionAsync(ct);
        row.Latitude = sample.Latitude;
        row.Longitude = sample.Longitude;
        row.AccuracyMeters = sample.AccuracyMeters;
        row.SpeedMps = sample.Speed;
        row.HeadingDegrees = sample.Heading;
        row.CapturedAt = sample.CapturedAt.ToUniversalTime();
        row.ReceivedAt = now;
        row.SessionLeaseUntil = now.AddSeconds(config.LeaseSeconds);
        row.ExpiresAt = now.AddHours(config.RetentionHours);
        await db.SaveChangesAsync(ct);
        await tx.CommitAsync(ct);
        return ToResponse(row, gate.Value);
    }

    public async Task<GpsTrackResponse?> GetLatestAsync(Guid bookingId, CancellationToken ct)
    {
        var now = clock.UtcNow;
        var result = await (
            from location in db.Set<LiveLocation>().AsNoTracking()
            join booking in db.Bookings.AsNoTracking() on location.BookingId equals booking.Id
            where location.BookingId == bookingId && location.ExpiresAt > now &&
                  location.Latitude != null && booking.Status == BookingStatus.CaregiverEnRoute &&
                  booking.CaregiverId == location.CaregiverId
            select new { Location = location, booking.SyncVersion }).SingleOrDefaultAsync(ct);
        return result is null ? null : ToResponse(result.Location, result.SyncVersion);
    }

    public Task<int> DeleteExpiredBatchAsync(CancellationToken ct) =>
        db.Database.ExecuteSqlRawAsync("""
            DELETE FROM booking.live_locations WHERE booking_id IN (
                SELECT l.booking_id FROM booking.live_locations l
                JOIN booking.bookings b ON b.id = l.booking_id
                WHERE l.expires_at <= now() OR upper(b.status) IN ('COMPLETED', 'CANCELLED', 'REFUNDED')
                ORDER BY l.booking_id LIMIT 500 FOR UPDATE OF l SKIP LOCKED)
            """, ct);

    private async Task<Result<long>> LockBookingAsync(Guid id, Guid caregiverId, bool exclusive, CancellationToken ct)
    {
        await db.Database.ExecuteSqlRawAsync("SET LOCAL lock_timeout = '2s'", ct);
        if (user.UserId is { } userId)
        {
            await db.Database.ExecuteSqlInterpolatedAsync($"SELECT set_config('app.current_user_id', {userId.ToString()}, true)", ct);
            await db.Database.ExecuteSqlInterpolatedAsync($"SELECT set_config('app.current_user_role', {string.Join(',', user.Roles)}, true)", ct);
        }
        await using var command = Command(
            "SELECT status, caregiver_id, sync_version FROM booking.bookings WHERE id = @id " +
            (exclusive ? "FOR UPDATE" : "FOR SHARE"));
        command.Parameters.AddWithValue("id", id);
        await using var reader = await command.ExecuteReaderAsync(ct);
        if (!await reader.ReadAsync(ct)) return BookingErrors.NotFound();
        if (reader.IsDBNull(1) || reader.GetGuid(1) != caregiverId) return BookingErrors.Forbidden();
        if (!string.Equals(reader.GetString(0), "CAREGIVER_EN_ROUTE", StringComparison.OrdinalIgnoreCase))
            return LiveTrackingErrors.NotEnRoute();
        return reader.GetInt64(2);
    }

    private Task<LiveLocation?> LockLocationAsync(Guid id, CancellationToken ct) =>
        db.Set<LiveLocation>().FromSqlInterpolated($"SELECT * FROM booking.live_locations WHERE booking_id = {id} FOR UPDATE")
            .SingleOrDefaultAsync(ct);

    private async Task<long> NextVersionAsync(CancellationToken ct)
    {
        await using var command = Command("SELECT nextval('booking.live_location_version_seq')");
        return (long)(await command.ExecuteScalarAsync(ct))!;
    }

    private NpgsqlCommand Command(string sql) => new(sql,
        (NpgsqlConnection)db.Database.GetDbConnection(),
        (NpgsqlTransaction)db.Database.CurrentTransaction!.GetDbTransaction());

    private static async Task<Result<T>> GuardAsync<T>(Func<Task<Result<T>>> operation)
    {
        try { return await operation(); }
        catch (PostgresException ex) when (ex.SqlState is "55P03" or "40P01" or "40001")
        { return LiveTrackingErrors.Unavailable(); }
        catch (DbUpdateException ex) when (ex.InnerException is PostgresException pg &&
            pg.SqlState is "55P03" or "40P01" or "40001")
        { return LiveTrackingErrors.Unavailable(); }
    }

    private static GpsTrackResponse ToResponse(LiveLocation row, long bookingVersion) => new(
        row.TrackingSessionId, row.BookingId, row.CaregiverId, row.Latitude!.Value,
        row.Longitude!.Value, row.AccuracyMeters, row.SpeedMps, row.HeadingDegrees,
        row.CapturedAt!.Value, row.LocationVersion, row.TrackingSessionId, row.ReceivedAt, bookingVersion);
}
