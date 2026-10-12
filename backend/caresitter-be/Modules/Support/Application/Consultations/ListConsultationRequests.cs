using CareSitter.Contracts.Services;
using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Support.Application.Consultations;

public sealed record ListConsultationRequests(int Page = 1, int PageSize = 20)
    : IRequest<Result<SupportPage<ConsultationResponse>>>;

internal sealed class ListConsultationRequestsHandler(
    IConsultationRequestStore store, ICurrentUser currentUser)
    : IRequestHandler<ListConsultationRequests, Result<SupportPage<ConsultationResponse>>>
{
    public async Task<Result<SupportPage<ConsultationResponse>>> Handle(
        ListConsultationRequests request, CancellationToken ct)
    {
        if (currentUser.UserId is null || !currentUser.IsInRole("ADMIN"))
            return Error.Forbidden("consultation.admin", "Chỉ quản trị viên được xem yêu cầu tư vấn.");
        return await store.ListAsync(Math.Clamp(request.Page, 1, 100000),
            Math.Clamp(request.PageSize, 1, 50), ct);
    }
}
