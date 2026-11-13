using CareSitter.Contracts.Services;
using CareSitter.SharedKernel.Results;

namespace CareSitter.Modules.Support.Application.Diagnostics;

public sealed class CrashReportService(ICrashReportSource source, ICurrentUser user, IClock clock)
{
    public Task<Result<CrashReportPage>> ListAsync(CrashReportFilter filter, CancellationToken ct)
    {
        if (user.UserId is null || !user.IsInRole("ADMIN"))
            return Task.FromResult<Result<CrashReportPage>>(Error.Forbidden("crash.admin_required", "Cần quyền Admin."));
        if (filter.Days is < 1 or > 7 || filter.Page is < 1 or > 100 || filter.PageSize is < 1 or > 50 ||
            filter.Until > clock.UtcNow.AddMinutes(5) || filter.Until < clock.UtcNow.AddDays(-30) ||
            filter.ErrorType is not (null or "FATAL" or "NON_FATAL" or "ANR"))
            return Task.FromResult<Result<CrashReportPage>>(Error.Validation("crash.filter", "Bộ lọc báo cáo không hợp lệ."));
        return source.ReadAsync(filter, ct);
    }
}
