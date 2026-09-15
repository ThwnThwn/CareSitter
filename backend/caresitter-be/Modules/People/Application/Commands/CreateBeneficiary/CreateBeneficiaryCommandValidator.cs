using FluentValidation;

namespace CareSitter.Modules.People.Application.Commands.CreateBeneficiary;

public sealed class CreateBeneficiaryCommandValidator : AbstractValidator<CreateBeneficiaryCommand>
{
    public CreateBeneficiaryCommandValidator()
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
    }

    private static string? NormalizeGender(string? value)
    {
        if (string.IsNullOrWhiteSpace(value)) return null;
        var gender = value.Trim().ToUpperInvariant();
        return gender is "MALE" or "FEMALE" or "OTHER" or "UNSPECIFIED" ? gender : string.Empty;
    }
}
