using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Booking.Application;

internal interface IChecklistTemplateManager
{
    Task<Result<ChecklistPolicyResponse>> SetPolicyAsync(
        Guid serviceTypeId, bool allowAdHocTasks, CancellationToken ct = default);
    Task<Result<IReadOnlyList<ChecklistTemplateResponse>>> ListAsync(
        Guid serviceTypeId, CancellationToken ct = default);
    Task<Result<ChecklistTemplateResponse>> CreateAsync(
        Guid serviceTypeId, ChecklistTemplateInput input, CancellationToken ct = default);
    Task<Result<ChecklistTemplateResponse>> UpdateAsync(
        Guid serviceTypeId, Guid templateId, ChecklistTemplateInput input,
        CancellationToken ct = default);
    Task<Result<ChecklistTemplateResponse>> SetActiveAsync(
        Guid serviceTypeId, Guid templateId, bool isActive, CancellationToken ct = default);
    Task<Result> DeleteAsync(
        Guid serviceTypeId, Guid templateId, CancellationToken ct = default);
}
