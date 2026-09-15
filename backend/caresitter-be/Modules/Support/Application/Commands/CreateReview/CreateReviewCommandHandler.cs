using CareSitter.Contracts.Services;
using CareSitter.Infrastructure.Security;
using CareSitter.Modules.Support.Domain;
using CareSitter.SharedKernel.Results;
using FluentValidation;
using MediatR;

namespace CareSitter.Modules.Support.Application.Commands.CreateReview;

internal sealed class CreateReviewCommandHandler(
    ISupportRepository repository,
    ICurrentUser currentUser,
    IReviewBookingLookup bookingLookup,
    IValidator<CreateReviewCommand> validator)
    : IRequestHandler<CreateReviewCommand, Result<ReviewResponse>>
{
    public async Task<Result<ReviewResponse>> Handle(
        CreateReviewCommand request, CancellationToken ct)
    {
        if (currentUser.UserId is not { } userId) return SupportErrors.Unauthenticated();
        var validation = await validator.ValidateAsync(request, ct);
        if (!validation.IsValid)
            return Error.Validation(validation.Errors[0].ErrorCode,
                validation.Errors[0].ErrorMessage);

        var comment = request.Comment?.Trim();
        var experienceTags = request.ExperienceTags?.Trim();

        var booking = await bookingLookup.GetForReviewAsync(request.BookingId, ct);
        if (booking is null) return SupportErrors.ReviewBookingNotFound();
        if (booking.CustomerId != userId) return SupportErrors.Forbidden();
        if (!booking.IsCompleted) return SupportErrors.ReviewBookingNotCompleted();
        if (booking.CaregiverId != request.CaregiverId)
            return SupportErrors.ReviewCaregiverMismatch();

        var exists = await repository.ReviewExistsAsync(request.BookingId, ct);
        if (exists) return SupportErrors.ReviewAlreadyExists();

        var created = Review.Create(request.BookingId, request.CaregiverId, userId,
            request.Rating, comment, experienceTags);
        if (created.IsFailure) return created.Error;

        if (!await repository.TryAddReviewAsync(created.Value, ct))
            return SupportErrors.ReviewConcurrentDuplicate();
        return SupportResponseMapper.ToResponse(created.Value);
    }
}
