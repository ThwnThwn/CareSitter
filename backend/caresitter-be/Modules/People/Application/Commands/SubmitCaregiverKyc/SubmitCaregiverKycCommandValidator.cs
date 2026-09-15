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
            if (!IsHttpUrl(request.CccdFrontUrl) || !IsHttpUrl(request.CccdBackUrl))
            {
                context.AddFailure(new ValidationFailure(nameof(request.CccdFrontUrl),
                    "Anh mat truoc va mat sau CCCD phai co URL hop le.")
                    { ErrorCode = PeopleErrors.InvalidCccdImageUrlsCode });
                return;
            }

            var certificateUrls = NormalizeUrls(request.CertificateUrls);
            if (certificateUrls.Length > 10 || certificateUrls.Any(x => !IsHttpUrl(x)))
                context.AddFailure(new ValidationFailure(nameof(request.CertificateUrls),
                    "Danh sach chung chi khong hop le hoac vuot qua 10 tep.")
                    { ErrorCode = PeopleErrors.InvalidCertificateUrlsCode });
        });
    }

    private static string[] NormalizeUrls(string[]? values) =>
        (values ?? Array.Empty<string>())
        .Where(x => !string.IsNullOrWhiteSpace(x))
        .Select(x => x.Trim())
        .Distinct(StringComparer.OrdinalIgnoreCase)
        .ToArray();

    private static bool IsHttpUrl(string? value) =>
        Uri.TryCreate(value, UriKind.Absolute, out var uri)
        && uri.Scheme is "http" or "https";
}
