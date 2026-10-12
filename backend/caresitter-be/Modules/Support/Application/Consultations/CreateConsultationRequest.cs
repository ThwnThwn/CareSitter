using CareSitter.Modules.Support.Domain;
using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Support.Application.Consultations;

public sealed record CreateConsultationRequest(Guid Id, string? ContactName, string? Phone,
    string? ServiceCategory, DateOnly PreferredDate, int Hours, string? CaregiverPreference,
    string? Note, bool Consent) : IRequest<Result<ConsultationReceipt>>;

internal sealed class CreateConsultationRequestHandler(IConsultationRequestStore store)
    : IRequestHandler<CreateConsultationRequest, Result<ConsultationReceipt>>
{
    public async Task<Result<ConsultationReceipt>> Handle(CreateConsultationRequest request,
        CancellationToken ct)
    {
        var result = ConsultationRequest.Create(request.Id, request.ContactName, request.Phone,
            request.ServiceCategory, request.PreferredDate, request.Hours,
            request.CaregiverPreference, request.Note, request.Consent, DateTime.UtcNow);
        if (result.IsFailure) return result.Error;
        return await store.SaveAsync(result.Value, ct);
    }
}
