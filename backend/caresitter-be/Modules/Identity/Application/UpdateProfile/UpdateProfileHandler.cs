using System.Net.Mail;
using CareSitter.Infrastructure.Security;
using CareSitter.Infrastructure.Time;
using CareSitter.Modules.Identity.Infrastructure;
using CareSitter.SharedKernel.Results;
using MediatR;
using Microsoft.EntityFrameworkCore;

namespace CareSitter.Modules.Identity.Application.UpdateProfile;

internal sealed class UpdateProfileHandler(
    IdentityDbContext db,
    ICurrentUser currentUser,
    IClock clock) : IRequestHandler<UpdateProfileCommand, Result<ProfileResponse>>
{
    private static readonly HashSet<string> AllowedGenders = new(StringComparer.OrdinalIgnoreCase)
        { "MALE", "FEMALE", "OTHER", "UNSPECIFIED" };

    public async Task<Result<ProfileResponse>> Handle(UpdateProfileCommand request, CancellationToken ct)
    {
        if (currentUser.UserId is not { } userId)
            return Error.Forbidden("profile.unauthenticated", "Không xác định được người dùng đang nhập.");

        var fullName = request.FullName?.Trim() ?? string.Empty;
        if (fullName.Length is < 2 or > 255)
            return Error.Validation("profile.invalid_full_name", "Ho ten phai co tu 2 den 255 ký tự.");

        var email = request.Email?.Trim().ToLowerInvariant() ?? string.Empty;
        if (email.Length > 255 || !MailAddress.TryCreate(email, out var parsedEmail) ||
            !string.Equals(parsedEmail.Address, email, StringComparison.OrdinalIgnoreCase))
            return Error.Validation("profile.invalid_email", "Email khong hop le.");

        var displayName = request.DisplayName?.Trim();
        if (displayName?.Length > 255)
            return Error.Validation("profile.invalid_display_name", "Tên hiển thị không được vượt quá 255 ký tự.");

        if (request.DateOfBirth > DateOnly.FromDateTime(clock.UtcNow.UtcDateTime))
            return Error.Validation("profile.invalid_date_of_birth", "Ngày sinh không được nằm trong tương lai.");

        var gender = string.IsNullOrWhiteSpace(request.Gender) ? null : request.Gender.Trim().ToUpperInvariant();
        if (gender is not null && !AllowedGenders.Contains(gender))
            return Error.Validation("profile.invalid_gender", "Gioi tinh phai la MALE, FEMALE, OTHER hoac UNSPECIFIED.");

        var user = await db.Users.SingleOrDefaultAsync(x => x.Id == userId && x.DeletedAt == null, ct);
        if (user is null)
            return Error.NotFound("profile.user_not_found", "Khong tim thay tai khoan người dùng.");

        if (await db.Users.AnyAsync(x => x.Id != userId && x.DeletedAt == null && x.Email == email, ct))
            return Error.Conflict("profile.email_exists", "Email đã được sử dụng bởi tài khoản khác.");

        user.UpdateProfile(fullName, email, displayName, request.DateOfBirth, gender);
        await db.SaveChangesAsync(ct);

        return new ProfileResponse(user.Id, user.Phone, user.Email, user.FullName!, user.DisplayName!,
            user.DateOfBirth, user.Gender, user.AvatarMediaId, user.AvatarUrl, user.DefaultAddressId, user.Roles);
    }
}
