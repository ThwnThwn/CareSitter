using System.Text.Json;
using CareSitter.Contracts.Services;
using CareSitter.Modules.Promotion.Application;
using CareSitter.Modules.Promotion.Domain;
using CareSitter.SharedKernel.Results;
using Microsoft.EntityFrameworkCore;
using Npgsql;

namespace CareSitter.Modules.Promotion.Infrastructure;

internal sealed class PromotionAdminStore(
    PromotionDbContext db, ICatalogLookupService catalog, IClock clock) : IPromotionAdminStore
{
    public async Task<AdminPromotionPage> ListAsync(string? search, string? status,
        int page, int pageSize, CancellationToken ct)
    {
        var now = clock.UtcNow;
        var query = db.Promotions.AsNoTracking();
        if (!string.IsNullOrWhiteSpace(search))
        {
            var text = search.Trim().ToUpperInvariant();
            query = query.Where(x => x.Code.ToUpper().Contains(text) || x.Title.ToUpper().Contains(text));
        }
        query = status switch
        {
            "ACTIVE" => query.Where(x => x.IsActive && x.StartsAt <= now && x.EndsAt >= now),
            "SCHEDULED" => query.Where(x => x.IsActive && x.StartsAt > now),
            "EXPIRED" => query.Where(x => x.IsActive && x.EndsAt < now),
            "INACTIVE" => query.Where(x => !x.IsActive),
            _ => query
        };
        var total = await query.CountAsync(ct);
        var items = await query.Include(x => x.ServiceScopes)
            .OrderByDescending(x => x.CreatedAt).ThenBy(x => x.Id)
            .Skip((page - 1) * pageSize).Take(pageSize).ToListAsync(ct);
        var ids = items.Select(x => x.Id).ToArray();
        var usage = await db.PromotionRedemptions.AsNoTracking()
            .Where(x => ids.Contains(x.PromotionId)).GroupBy(x => x.PromotionId)
            .Select(g => new Usage(g.Key,
                g.Count(x => x.Status == PromotionRedemptionStatus.Reserved && x.ExpiresAt >= now),
                g.Count(x => x.Status == PromotionRedemptionStatus.Redeemed),
                g.Count(x => x.Status == PromotionRedemptionStatus.Released), g.Count()))
            .ToDictionaryAsync(x => x.Id, ct);
        return new AdminPromotionPage(items.Select(x => Map(x, usage.GetValueOrDefault(x.Id), now)).ToArray(),
            total, page, pageSize);
    }

    public async Task<AdminPromotionResponse?> GetAsync(Guid id, CancellationToken ct)
    {
        var promotion = await db.Promotions.AsNoTracking().Include(x => x.ServiceScopes)
            .SingleOrDefaultAsync(x => x.Id == id, ct);
        return promotion is null ? null : await ResponseAsync(promotion, ct);
    }

    public async Task<Result<AdminPromotionChange>> CreateAsync(PromotionConfiguration configuration, CancellationToken ct)
    {
        var created = Domain.Promotion.Create(configuration);
        if (created.IsFailure) return created.Error;
        var services = await CheckServicesAsync(configuration.EligibleServiceIds, ct);
        if (services.IsFailure) return services.Error;
        if (await CodeExistsAsync(created.Value.Code, null, ct)) return CodeExists();
        db.Promotions.Add(created.Value);
        try
        {
            await db.SaveChangesAsync(ct);
        }
        catch (DbUpdateException ex) when (IsConstraint(ex, PostgresErrorCodes.UniqueViolation))
        {
            db.ChangeTracker.Clear();
            return CodeExists();
        }
        catch (DbUpdateException ex) when (IsConstraint(ex, PostgresErrorCodes.ForeignKeyViolation))
        {
            db.ChangeTracker.Clear();
            return InvalidServices();
        }
        await db.Entry(created.Value).ReloadAsync(ct);
        return new AdminPromotionChange(null, await ResponseAsync(created.Value, ct));
    }

    public async Task<Result<AdminPromotionChange>> UpdateAsync(Guid id, PromotionConfiguration configuration,
        DateTimeOffset expectedUpdatedAt, CancellationToken ct)
    {
        var valid = configuration.Validate();
        if (valid.IsFailure) return valid.Error;
        await using var transaction = await db.Database.BeginTransactionAsync(ct);
        var promotion = await LockAsync(id, ct);
        if (promotion is null) return PromotionErrors.NotFound();
        if (promotion.UpdatedAt != expectedUpdatedAt) return Stale();
        var before = await ResponseAsync(promotion, ct);
        if (before.HasHistory && !promotion.HasSameBookingRules(configuration))
            return Error.Conflict("promotion.rules_locked",
                "Chiến dịch đã có lịch sử giữ hoặc sử dụng. Hãy tạo chiến dịch mới để đổi mã, mức giảm hoặc điều kiện áp dụng.");
        var activeUsage = db.PromotionRedemptions.AsNoTracking().Where(x => x.PromotionId == id &&
            (x.Status == PromotionRedemptionStatus.Redeemed ||
                (x.Status == PromotionRedemptionStatus.Reserved && x.ExpiresAt >= clock.UtcNow)));
        if (configuration.TotalUsageLimit is { } limit && limit < await activeUsage.CountAsync(ct))
            return Error.Conflict("promotion.quota_below_usage", "Giới hạn tổng lượt không thể thấp hơn số lượt đang giữ và đã sử dụng.");
        if (await activeUsage.GroupBy(x => x.CustomerId)
            .AnyAsync(g => g.Count() > configuration.PerCustomerUsageLimit, ct))
            return Error.Conflict("promotion.customer_quota_below_usage", "Giới hạn mỗi khách không thể thấp hơn lượt đang giữ và đã sử dụng của khách.");
        var newScopes = configuration.EligibleServiceIds.Except(promotion.ServiceScopes.Select(x => x.ServiceTypeId));
        var services = await CheckServicesAsync(newScopes, ct);
        if (services.IsFailure) return services.Error;
        if (await CodeExistsAsync(configuration.Code.Trim().ToUpperInvariant(), id, ct)) return CodeExists();
        promotion.Configure(configuration);
        // Scope-only and no-op updates must also advance the edit token.
        db.Entry(promotion).Property(x => x.UpdatedAt).IsModified = true;
        try
        {
            await db.SaveChangesAsync(ct);
        }
        catch (DbUpdateException ex) when (IsConstraint(ex, PostgresErrorCodes.UniqueViolation))
        {
            db.ChangeTracker.Clear();
            return CodeExists();
        }
        catch (DbUpdateException ex) when (IsConstraint(ex, PostgresErrorCodes.ForeignKeyViolation))
        {
            db.ChangeTracker.Clear();
            return InvalidServices();
        }
        await db.Entry(promotion).ReloadAsync(ct);
        var after = await ResponseAsync(promotion, ct);
        await transaction.CommitAsync(ct);
        return new AdminPromotionChange(before, after);
    }

    public async Task<Result<AdminPromotionChange>> SetActiveAsync(Guid id, bool isActive,
        DateTimeOffset expectedUpdatedAt, CancellationToken ct)
    {
        await using var transaction = await db.Database.BeginTransactionAsync(ct);
        var promotion = await LockAsync(id, ct);
        if (promotion is null) return PromotionErrors.NotFound();
        if (promotion.UpdatedAt != expectedUpdatedAt) return Stale();
        var before = await ResponseAsync(promotion, ct);
        promotion.SetActive(isActive);
        db.Entry(promotion).Property(x => x.UpdatedAt).IsModified = true;
        await db.SaveChangesAsync(ct);
        await db.Entry(promotion).ReloadAsync(ct);
        var after = await ResponseAsync(promotion, ct);
        await transaction.CommitAsync(ct);
        return new AdminPromotionChange(before, after);
    }

    public async Task<Result<AdminPromotionChange>> DeleteAsync(Guid id,
        DateTimeOffset expectedUpdatedAt, CancellationToken ct)
    {
        await using var transaction = await db.Database.BeginTransactionAsync(ct);
        var promotion = await LockAsync(id, ct);
        if (promotion is null) return PromotionErrors.NotFound();
        if (promotion.UpdatedAt != expectedUpdatedAt) return Stale();
        var before = await ResponseAsync(promotion, ct);
        if (!before.CanDelete)
            return Error.Conflict("promotion.has_history", "Chiến dịch đã có lịch sử. Hãy tắt chiến dịch để giữ dữ liệu booking và đối soát.");
        db.Promotions.Remove(promotion);
        await db.SaveChangesAsync(ct);
        await transaction.CommitAsync(ct);
        return new AdminPromotionChange(before, null);
    }

    private async Task<Domain.Promotion?> LockAsync(Guid id, CancellationToken ct)
    {
        // Reservation uses the same row lock, so admin writes cannot race quota allocation.
        var promotion = await db.Promotions
            .FromSqlInterpolated($"SELECT * FROM promotion.promotions WHERE id = {id} FOR UPDATE")
            .SingleOrDefaultAsync(ct);
        if (promotion is not null)
            await db.Entry(promotion).Collection(x => x.ServiceScopes).LoadAsync(ct);
        return promotion;
    }

    private async Task<Result> CheckServicesAsync(IEnumerable<Guid> ids, CancellationToken ct)
    {
        foreach (var id in ids)
            if (await catalog.GetServiceDisplayAsync(id, ct) is null) return InvalidServices();
        return Result.Success();
    }

    private Task<bool> CodeExistsAsync(string code, Guid? exceptId, CancellationToken ct) =>
        db.Promotions.AnyAsync(x => x.Code == code && (exceptId == null || x.Id != exceptId), ct);

    private async Task<AdminPromotionResponse> ResponseAsync(Domain.Promotion promotion, CancellationToken ct)
    {
        var now = clock.UtcNow;
        var usage = await db.PromotionRedemptions.AsNoTracking().Where(x => x.PromotionId == promotion.Id)
            .GroupBy(x => x.PromotionId).Select(g => new Usage(g.Key,
                g.Count(x => x.Status == PromotionRedemptionStatus.Reserved && x.ExpiresAt >= now),
                g.Count(x => x.Status == PromotionRedemptionStatus.Redeemed),
                g.Count(x => x.Status == PromotionRedemptionStatus.Released), g.Count()))
            .SingleOrDefaultAsync(ct);
        return Map(promotion, usage, now);
    }

    private static AdminPromotionResponse Map(Domain.Promotion p, Usage? usage, DateTimeOffset now) => new(
        p.Id, p.Code, p.Title, p.Summary, p.Description, p.BadgeText,
        JsonSerializer.Deserialize<string[]>(p.TermsJson) ?? [],
        p.DiscountType == PromotionDiscountType.Percentage ? "percentage" : "fixed_amount",
        p.DiscountValue, p.MaxDiscountAmount, p.MinOrderAmount, p.StartsAt, p.EndsAt, p.IsActive,
        p.FirstPaidBookingOnly, p.TotalUsageLimit, p.PerCustomerUsageLimit, p.Priority, p.IsFeatured,
        p.ServiceScopes.Select(x => x.ServiceTypeId).Order().ToArray(),
        !p.IsActive ? "INACTIVE" : p.StartsAt > now ? "SCHEDULED" : p.EndsAt < now ? "EXPIRED" : "ACTIVE",
        usage?.Reserved ?? 0, usage?.Redeemed ?? 0, usage?.Released ?? 0,
        usage is { Total: > 0 }, usage is null or { Total: 0 }, p.CreatedAt, p.UpdatedAt);

    private sealed record Usage(Guid Id, int Reserved, int Redeemed, int Released, int Total);
    private static bool IsConstraint(DbUpdateException ex, string state) =>
        ex.InnerException is PostgresException pg && pg.SqlState == state;
    private static Error CodeExists() => Error.Conflict("promotion.code_exists", "Mã ưu đãi đã tồn tại.");
    private static Error InvalidServices() => Error.Validation("promotion.invalid_services", "Dịch vụ áp dụng không tồn tại hoặc đã ngừng hoạt động.");
    private static Error Stale() => Error.Conflict("promotion.stale", "Chiến dịch đã được người khác thay đổi. Hãy tải lại trước khi lưu.");
}
