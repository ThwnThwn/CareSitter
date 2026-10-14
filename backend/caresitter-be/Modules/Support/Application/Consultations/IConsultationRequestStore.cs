using CareSitter.Modules.Support.Domain;
using CareSitter.SharedKernel.Results;

namespace CareSitter.Modules.Support.Application.Consultations;

public interface IConsultationRequestStore
{
    Task<Result<ConsultationReceipt>> SaveAsync(ConsultationRequest request, CancellationToken ct);
    Task<SupportPage<ConsultationResponse>> ListAsync(int page, int pageSize, CancellationToken ct);
}
