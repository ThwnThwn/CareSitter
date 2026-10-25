using CareSitter.Contracts.Services;
using CareSitter.Modules.People.Infrastructure;
using Microsoft.EntityFrameworkCore;

namespace CareSitter.Modules.People.Infrastructure;

/// <summary>
/// Triển khai <see cref="IPeopleLookupService"/> — cung cấp các truy vấn kiểm tra
/// quyền sở hữu và tính khả dụng của Caregiver/Beneficiary xuyên module.
/// Được inject vào BookingModule, BookingsController và các Application Handlers.
/// </summary>
internal sealed class PeopleLookupService(
    PeopleDbContext db,
    IUserProfileReader userProfiles) : IPeopleLookupService
{
    /// <summary>
    /// Kiểm tra xem một người thân (Beneficiary) có thuộc về
    /// khách hàng (<paramref name="customerId"/>) hay không.
    /// Sử dụng RLS PostgreSQL để cách ly dữ liệu: bắt đầu transaction và gán
    /// <c>app.current_user_id</c> trước khi truy vấn để RLS tự lọc đúng user.
    /// </summary>
    /// <param name="beneficiaryId">ID hồ sơ người thân cần kiểm tra.</param>
    /// <param name="customerId">ID của khách hàng (User.Id) đang thực hiện thao tác.</param>
    /// <param name="ct">Token hủy tác vụ bất đồng bộ.</param>
    /// <returns><c>true</c> nếu hồ sơ người thân thuộc về khách hàng và chưa bị xóa.</returns>
    public async Task<bool> BeneficiaryBelongsToAsync(Guid beneficiaryId, Guid customerId,
        CancellationToken ct = default)
    {
        await using var transaction = await db.Database.BeginTransactionAsync(ct);
        await db.Database.ExecuteSqlInterpolatedAsync(
            $"SELECT set_config('app.current_user_id', {customerId.ToString()}, true)", ct);
        return await db.Beneficiaries.AnyAsync(x => x.Id == beneficiaryId &&
            x.CustomerId == customerId && x.DeletedAt == null, ct);
    }

    /// <summary>
    /// Kiểm tra caregiver có profile đã được duyệt, đang ONLINE và chưa bị xóa.
    /// Việc kiểm tra trùng lịch thực tế được thực hiện trên booking khi nhận ca.
    /// </summary>
    /// <param name="caregiverId">ID của CaregiverProfile.</param>
    /// <param name="start">Thời điểm bắt đầu ca cần kiểm tra.</param>
    /// <param name="end">Thời điểm kết thúc ca cần kiểm tra.</param>
    /// <param name="ct">Token hủy tác vụ bất đồng bộ.</param>
    /// <returns><c>true</c> khi caregiver đã được duyệt KYC và đang ONLINE.</returns>
    public async Task<bool> CaregiverIsAvailableAsync(Guid caregiverId, DateTimeOffset start,
        DateTimeOffset end, CancellationToken ct = default)
    {
        var caregiver = await db.CaregiverProfiles.AsNoTracking().AnyAsync(x =>
            x.Id == caregiverId && x.DeletedAt == null && x.KycStatus == "APPROVED"
            && x.AvailabilityStatus == "ONLINE", ct);
        if (!caregiver)
            return false;

        return caregiver;
    }

    /// <summary>
    /// Kiểm tra nhanh xem một CaregiverProfile có trạng thái KYC là APPROVED không.
    /// Dùng khi cần xác thực tư cách hành nghề của caregiver mà không cần kiểm tra lịch.
    /// </summary>
    /// <param name="caregiverId">ID của CaregiverProfile.</param>
    /// <param name="ct">Token hủy tác vụ bất đồng bộ.</param>
    /// <returns><c>true</c> nếu caregiver đã được duyệt KYC và chưa bị xóa.</returns>
    public Task<bool> IsCaregiverApprovedAsync(Guid caregiverId, CancellationToken ct = default) =>
        db.CaregiverProfiles.AsNoTracking().AnyAsync(x =>
            x.Id == caregiverId && x.DeletedAt == null && x.KycStatus == "APPROVED", ct);

    /// <summary>
    /// Xác minh rằng một <c>userId</c> (Identity user) chính là chủ sở hữu của
    /// <c>caregiverId</c> (CaregiverProfile). Dùng trong lifecycle endpoints (accept,
    /// en-route, check-in, checkout) để đảm bảo chỉ đúng caregiver được phân công
    /// mới có thể thực hiện thao tác trên booking.
    /// </summary>
    /// <param name="caregiverId">ID của CaregiverProfile được phân công cho booking.</param>
    /// <param name="userId">ID của User hiện tại đang gọi API (lấy từ JWT claim).</param>
    /// <param name="ct">Token hủy tác vụ bất đồng bộ.</param>
    /// <returns>
    /// <c>true</c> nếu CaregiverProfile có <c>UserId == userId</c> và chưa bị xóa.
    /// </returns>
    public async Task<bool> IsCaregiverForBookingAsync(Guid caregiverId, Guid userId, CancellationToken ct = default) =>
        await db.CaregiverProfiles.AsNoTracking().AnyAsync(x =>
            x.Id == caregiverId && x.UserId == userId && x.DeletedAt == null, ct);

    /// <summary>
    /// Lấy CaregiverProfile.Id tương ứng với một userId (Identity user).
    /// Dùng trong <c>BookingsController.List/Get</c> để map từ JWT user identity
    /// sang CaregiverProfile.Id nhằm lọc danh sách ca trực của caregiver đó.
    /// </summary>
    /// <param name="userId">User.Id lấy từ JWT claim của caregiver đang đăng nhập.</param>
    /// <param name="ct">Token hủy tác vụ bất đồng bộ.</param>
    /// <returns>
    /// <see cref="Guid"/> của CaregiverProfile, hoặc <c>null</c> nếu user chưa có
    /// profile caregiver (chưa nộp KYC hoặc hồ sơ bị xóa).
    /// </returns>
    public async Task<Guid?> GetCaregiverProfileIdByUserIdAsync(Guid userId, CancellationToken ct = default)
    {
        var profile = await db.CaregiverProfiles.AsNoTracking()
            .FirstOrDefaultAsync(x => x.UserId == userId && x.DeletedAt == null, ct);
        return profile?.Id;
    }

    /// <summary>
    /// Lấy User.Id tương ứng với một CaregiverProfile.Id để các module khác có thể
    /// gửi notification/push cho caregiver mà không query chéo DbContext.
    /// </summary>
    public async Task<Guid?> GetUserIdByCaregiverProfileIdAsync(Guid caregiverId, CancellationToken ct = default)
    {
        var profile = await db.CaregiverProfiles.AsNoTracking()
            .FirstOrDefaultAsync(x => x.Id == caregiverId && x.DeletedAt == null, ct);
        return profile?.UserId;
    }

    public async Task<PeopleDisplaySummary?> GetBeneficiaryDisplayAsync(Guid beneficiaryId, CancellationToken ct = default)
    {
        var beneficiary = await db.Beneficiaries.AsNoTracking()
            .Where(x => x.Id == beneficiaryId && x.DeletedAt == null)
            .Select(x => new
            {
                x.Id,
                x.FullName,
                x.DateOfBirth,
                x.Gender,
                x.AvatarUrl,
                x.RelationshipToCustomer,
                x.MobilityNote,
                x.GeneralNote,
                x.CareInstructions
            })
            .SingleOrDefaultAsync(ct);

        if (beneficiary is null || string.IsNullOrWhiteSpace(beneficiary.FullName))
            return null;

        int? age = null;
        if (beneficiary.DateOfBirth.HasValue)
        {
            var today = DateOnly.FromDateTime(DateTime.UtcNow);
            age = today.Year - beneficiary.DateOfBirth.Value.Year;
            if (beneficiary.DateOfBirth.Value > today.AddYears(-age.Value)) age--;
        }

        var condition = !string.IsNullOrWhiteSpace(beneficiary.MobilityNote)
            ? beneficiary.MobilityNote
            : (!string.IsNullOrWhiteSpace(beneficiary.GeneralNote) ? beneficiary.GeneralNote : null);

        var notes = !string.IsNullOrWhiteSpace(beneficiary.CareInstructions)
            ? beneficiary.CareInstructions
            : (!string.IsNullOrWhiteSpace(beneficiary.GeneralNote) ? beneficiary.GeneralNote : null);

        return new PeopleDisplaySummary(
            beneficiary.Id,
            beneficiary.FullName,
            age,
            beneficiary.Gender,
            beneficiary.RelationshipToCustomer,
            condition,
            notes,
            beneficiary.AvatarUrl);
    }

    public async Task<PeopleDisplaySummary?> GetCaregiverDisplayAsync(Guid caregiverId, CancellationToken ct = default)
    {
        var caregiver = await db.CaregiverProfiles.AsNoTracking()
            .Where(x => x.Id == caregiverId && x.DeletedAt == null)
            .Select(x => new { x.Id, x.UserId, x.FullName })
            .SingleOrDefaultAsync(ct);
        if (caregiver is null || string.IsNullOrWhiteSpace(caregiver.FullName))
            return null;

        var avatarUrl = await userProfiles.GetAvatarUrlAsync(caregiver.UserId, ct);
        return new PeopleDisplaySummary(
            caregiver.Id,
            caregiver.FullName,
            AvatarUrl: avatarUrl);
    }
}
