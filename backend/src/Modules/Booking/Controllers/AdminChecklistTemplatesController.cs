using CareSitter.Modules.Booking.Application;
using MediatR;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace CareSitter.Modules.Booking.Controllers;

[ApiController]
[Authorize(Roles = "ADMIN")]
[Route("api/v1/admin/services/{serviceTypeId:guid}/checklist-templates")]
public sealed class AdminChecklistTemplatesController : ControllerBase
{
    private readonly IMediator _mediator;

    public AdminChecklistTemplatesController(IMediator mediator)
    {
        _mediator = mediator;
    }

    [HttpPatch("/api/v1/admin/services/{serviceTypeId:guid}/checklist-policy")]
    public async Task<IActionResult> SetPolicy(
        Guid serviceTypeId, [FromBody] ChecklistPolicyRequest request, CancellationToken ct)
    {
        var result = await _mediator.Send(
            new SetChecklistPolicyCommand(serviceTypeId, request.AllowAdHocTasks), ct);
        return result.ToActionResult(this);
    }

    [HttpGet]
    public async Task<IActionResult> List(Guid serviceTypeId, CancellationToken ct)
    {
        var result = await _mediator.Send(new ListChecklistTemplatesQuery(serviceTypeId), ct);
        return result.ToActionResult(this);
    }

    [HttpPost]
    public async Task<IActionResult> Create(
        Guid serviceTypeId, [FromBody] UpsertChecklistTemplateRequest request, CancellationToken ct)
    {
        var result = await _mediator.Send(new CreateChecklistTemplateCommand(
            serviceTypeId, ToInput(request)), ct);
        return result.ToActionResult(this, value => Created(
            $"/api/v1/admin/services/{serviceTypeId}/checklist-templates/{value.Id}", value));
    }

    [HttpPut("{templateId:guid}")]
    public async Task<IActionResult> Update(
        Guid serviceTypeId, Guid templateId,
        [FromBody] UpsertChecklistTemplateRequest request, CancellationToken ct)
    {
        var result = await _mediator.Send(new UpdateChecklistTemplateCommand(
            serviceTypeId, templateId, ToInput(request)), ct);
        return result.ToActionResult(this);
    }

    [HttpPatch("{templateId:guid}/active")]
    public async Task<IActionResult> SetActive(
        Guid serviceTypeId, Guid templateId,
        [FromBody] SetChecklistTemplateActiveRequest request, CancellationToken ct)
    {
        var result = await _mediator.Send(new SetChecklistTemplateActiveCommand(
            serviceTypeId, templateId, request.IsActive), ct);
        return result.ToActionResult(this);
    }

    [HttpDelete("{templateId:guid}")]
    public async Task<IActionResult> Delete(
        Guid serviceTypeId, Guid templateId, CancellationToken ct)
    {
        var result = await _mediator.Send(
            new DeleteChecklistTemplateCommand(serviceTypeId, templateId), ct);
        return result.ToActionResult(this, NoContent);
    }

    private static ChecklistTemplateInput ToInput(UpsertChecklistTemplateRequest request) =>
        new(request.Name, request.Description, request.IsRequired,
            request.RequiresPhoto, request.SortOrder);
}
