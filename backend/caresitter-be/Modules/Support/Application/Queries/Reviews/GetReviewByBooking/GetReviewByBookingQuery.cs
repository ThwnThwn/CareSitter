using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Support.Application;

public sealed record GetReviewByBookingQuery(Guid BookingId) : IRequest<Result<ReviewResponse>>;
