using FluentValidation;

namespace CareSitter.Modules.People.Application.Commands.UpdateBeneficiary;

public sealed class UpdateBeneficiaryCommandValidator : AbstractValidator<UpdateBeneficiaryCommand>
{
    public UpdateBeneficiaryCommandValidator()
    {
        RuleFor(x => x.Gender)
            .Must(value => NormalizeGender(value) != string.Empty)
            .WithErrorCode("beneficiary.gender")
            .WithMessage("Giới tính không hợp lệ.");
        RuleFor(x => x.DateOfBirth)
            .Must(value => value is null || value <= DateOnly.FromDateTime(DateTime.UtcNow))
            .WithErrorCode("beneficiary.date_of_birth")
            .WithMessage("Ngày sinh không được ở tương lai.");
        RuleFor(x => x.DefaultAddressId)
            .NotNull()
            .WithErrorCode("beneficiary.address_required")
            .WithMessage("Vui lòng chọn địa chỉ đã xác minh cho người được chăm sóc.");
        RuleFor(x => x.CareLevel)
            .Must(IsValidCareLevel)
            .WithErrorCode("beneficiary.care_level")
            .WithMessage("Mức độ chăm sóc không hợp lệ.");
        RuleFor(x => x.AvatarUrl)
            .MaximumLength(2048)
            .Must(IsValidAvatarUrl)
            .WithErrorCode("beneficiary.avatar_url")
            .WithMessage("URL ảnh đại diện không hợp lệ.");
    }

    private static string? NormalizeGender(string? value)
    {
        if (string.IsNullOrWhiteSpace(value)) return null;
        var gender = value.Trim().ToUpperInvariant();
        return gender is "MALE" or "FEMALE" or "OTHER" or "UNSPECIFIED" ? gender : string.Empty;
    }

    private static bool IsValidCareLevel(string? value) =>
        string.IsNullOrWhiteSpace(value) || value.Trim() is "Nhẹ" or "Trung bình" or "Nặng";

    private static bool IsValidAvatarUrl(string? value)
    {
        if (string.IsNullOrWhiteSpace(value)) return true;
        return Uri.TryCreate(value.Trim(), UriKind.Absolute, out var uri) &&
               uri.Scheme is "http" or "https";
    }
}
