using CareSitter.Contracts.Services;
using CareSitter.Modules.Support.Application.Commands;
using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Support.Application;

internal sealed class ListCaregiverReviewsQueryHandler(
    ISupportReadStore store) : IRequestHandler<ListCaregiverReviewsQuery, SupportPage<ReviewResponse>>
{
    public Task<SupportPage<ReviewResponse>> Handle(ListCaregiverReviewsQuery request, CancellationToken ct) =>
        store.ListCaregiverReviewsAsync(request.CaregiverId, Math.Max(request.Page, 1),
            Math.Clamp(request.PageSize, 1, 50), ct);
}
