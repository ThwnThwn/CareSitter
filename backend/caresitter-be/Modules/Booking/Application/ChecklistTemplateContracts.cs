using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Booking.Application;

public sealed record ChecklistTemplateResponse(
    Guid Id, Guid ServiceTypeId, string Name, string? Description,
    bool IsRequired, bool RequiresPhoto, int SortOrder, bool IsActive);
public sealed record ChecklistPolicyResponse(Guid Id, bool AllowAdHocTasks);
public sealed record ChecklistTemplateInput(
    string Name, string? Description, bool IsRequired, bool RequiresPhoto, int SortOrder);

public sealed record SetChecklistPolicyCommand(Guid ServiceTypeId, bool AllowAdHocTasks)
    : IRequest<Result<ChecklistPolicyResponse>>;
public sealed record ListChecklistTemplatesQuery(Guid ServiceTypeId)
    : IRequest<Result<IReadOnlyList<ChecklistTemplateResponse>>>;
public sealed record CreateChecklistTemplateCommand(Guid ServiceTypeId, ChecklistTemplateInput Input)
    : IRequest<Result<ChecklistTemplateResponse>>;
public sealed record UpdateChecklistTemplateCommand(
    Guid ServiceTypeId, Guid TemplateId, ChecklistTemplateInput Input)
    : IRequest<Result<ChecklistTemplateResponse>>;
public sealed record SetChecklistTemplateActiveCommand(
    Guid ServiceTypeId, Guid TemplateId, bool IsActive)
    : IRequest<Result<ChecklistTemplateResponse>>;
public sealed record DeleteChecklistTemplateCommand(Guid ServiceTypeId, Guid TemplateId)
    : IRequest<Result>;

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

internal sealed class ChecklistTemplateHandlers(IChecklistTemplateManager manager) :
    IRequestHandler<SetChecklistPolicyCommand, Result<ChecklistPolicyResponse>>,
    IRequestHandler<ListChecklistTemplatesQuery, Result<IReadOnlyList<ChecklistTemplateResponse>>>,
    IRequestHandler<CreateChecklistTemplateCommand, Result<ChecklistTemplateResponse>>,
    IRequestHandler<UpdateChecklistTemplateCommand, Result<ChecklistTemplateResponse>>,
    IRequestHandler<SetChecklistTemplateActiveCommand, Result<ChecklistTemplateResponse>>,
    IRequestHandler<DeleteChecklistTemplateCommand, Result>
{
    public Task<Result<ChecklistPolicyResponse>> Handle(
        SetChecklistPolicyCommand request, CancellationToken ct) =>
        manager.SetPolicyAsync(request.ServiceTypeId, request.AllowAdHocTasks, ct);
    public Task<Result<IReadOnlyList<ChecklistTemplateResponse>>> Handle(
        ListChecklistTemplatesQuery request, CancellationToken ct) =>
        manager.ListAsync(request.ServiceTypeId, ct);
    public Task<Result<ChecklistTemplateResponse>> Handle(
        CreateChecklistTemplateCommand request, CancellationToken ct) =>
        manager.CreateAsync(request.ServiceTypeId, request.Input, ct);
    public Task<Result<ChecklistTemplateResponse>> Handle(
        UpdateChecklistTemplateCommand request, CancellationToken ct) =>
        manager.UpdateAsync(request.ServiceTypeId, request.TemplateId, request.Input, ct);
    public Task<Result<ChecklistTemplateResponse>> Handle(
        SetChecklistTemplateActiveCommand request, CancellationToken ct) =>
        manager.SetActiveAsync(request.ServiceTypeId, request.TemplateId, request.IsActive, ct);
    public Task<Result> Handle(DeleteChecklistTemplateCommand request, CancellationToken ct) =>
        manager.DeleteAsync(request.ServiceTypeId, request.TemplateId, ct);
}
