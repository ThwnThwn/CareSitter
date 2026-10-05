using FluentValidation;
using FluentValidation.Results;

namespace CareSitter.Modules.Support.Application.Commands.CreateSupportTicket;

public sealed class CreateSupportTicketCommandValidator
    : AbstractValidator<CreateSupportTicketCommand>
{
    public CreateSupportTicketCommandValidator()
    {
        RuleFor(x => x).Custom((request, context) =>
        {
            var attachmentUrls = NormalizeUrls(request.AttachmentUrls);
            if (attachmentUrls.Length > 5 || attachmentUrls.Any(x => !IsHttpUrl(x)))
                context.AddFailure(new ValidationFailure(nameof(request.AttachmentUrls),
                    "Danh sach tep dinh kem khong hop le hoac vuot qua 5 tep.")
                    { ErrorCode = SupportErrors.InvalidAttachmentsCode });
        });
    }

    private static string[] NormalizeUrls(string[]? values) =>
        (values ?? Array.Empty<string>())
        .Where(x => !string.IsNullOrWhiteSpace(x))
        .Select(x => x.Trim())
        .Distinct(StringComparer.OrdinalIgnoreCase)
        .ToArray();

    private static bool IsHttpUrl(string value) =>
        Uri.TryCreate(value, UriKind.Absolute, out var uri)
        && uri.Scheme is "http" or "https";
}
