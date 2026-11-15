using FluentValidation;
using FluentValidation.Results;

namespace CareSitter.Modules.Support.Application.Commands.CreateReview;

public sealed class CreateReviewCommandValidator : AbstractValidator<CreateReviewCommand>
{
    public CreateReviewCommandValidator()
    {
        RuleFor(x => x).Custom((request, context) =>
        {
            if (request.BookingId == Guid.Empty || request.CaregiverId == Guid.Empty)
            {
                context.AddFailure(new ValidationFailure(nameof(request.BookingId),
                    "Booking và caregiver là bắt buộc.")
                    { ErrorCode = SupportErrors.ReviewRequiredIdsCode });
                return;
            }

            var comment = request.Comment?.Trim();
            var experienceTags = request.ExperienceTags?.Trim();
            if (comment?.Length > 1_000)
            {
                context.AddFailure(new ValidationFailure(nameof(request.Comment),
                    "Nội dung đánh giá không được vượt quá 1000 ký tự.")
                    { ErrorCode = SupportErrors.ReviewCommentTooLongCode });
                return;
            }
            if (experienceTags?.Length > 1_000)
                context.AddFailure(new ValidationFailure(nameof(request.ExperienceTags),
                    "Danh sách trải nghiệm không được vượt quá 1000 ký tự.")
                    { ErrorCode = SupportErrors.ReviewTagsTooLongCode });
        });
    }
}
