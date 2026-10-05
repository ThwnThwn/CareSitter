using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Support.Application;

public sealed record ListCaregiverReviewsQuery(
    Guid CaregiverId, int Page, int PageSize) : IRequest<SupportPage<ReviewResponse>>;
