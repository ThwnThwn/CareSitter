using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Support.Application.Commands.CreateReview;

public sealed record CreateReviewCommand(Guid BookingId, Guid CaregiverId,
    int Rating, string? Comment, string? ExperienceTags)
    : IRequest<Result<ReviewResponse>>;
