using FluentValidation;
using FluentValidation.Results;

namespace CareSitter.Modules.People.Application.Commands.SubmitCaregiverKyc;

public sealed class SubmitCaregiverKycCommandValidator
    : AbstractValidator<SubmitCaregiverKycCommand>
{
    public SubmitCaregiverKycCommandValidator()
    {
        RuleFor(x => x).Custom((request, context) =>
        {
            var cccdNumber = request.CccdNumber?.Trim() ?? string.Empty;
            if (cccdNumber.Length is not (9 or 12) || !cccdNumber.All(char.IsDigit))
            {
                context.AddFailure(new ValidationFailure(nameof(request.CccdNumber),
                    "So CCCD phai gom 9 hoac 12 chu so.")
                    { ErrorCode = PeopleErrors.InvalidCccdCode });
                return;
            }
            if (request.CccdFrontMediaId == Guid.Empty || request.CccdBackMediaId == Guid.Empty)
            {
                context.AddFailure(new ValidationFailure(nameof(request.CccdFrontMediaId),
                    "Cần tải lên hai mặt CCCD bằng media an toàn; không chấp nhận URL ảnh.")
                    { ErrorCode = PeopleErrors.InvalidCccdImageUrlsCode });
                return;
            }

            var certificates = request.CertificateMediaIds ?? [];
            if (certificates.Length > 10 || certificates.Contains(Guid.Empty))
                context.AddFailure(new ValidationFailure(nameof(request.CertificateMediaIds),
                    "Danh sach chung chi khong hop le hoac vuot qua 10 tep.")
                    { ErrorCode = PeopleErrors.InvalidCertificateUrlsCode });
        });
    }

}
