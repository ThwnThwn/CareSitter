using CareSitter.Modules.People.Application;
using CareSitter.Modules.People.Application.Commands.CreateFamilyContact;
using CareSitter.Modules.People.Application.Commands.DeleteFamilyContact;
using CareSitter.Modules.People.Application.Commands.UpdateFamilyContact;
using MediatR;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace CareSitter.Modules.People.Controllers;

[ApiController]
[Authorize]
[Route("api/v1/family-contacts")]
public sealed class FamilyContactsController : ControllerBase
{
    private readonly IMediator _mediator;

    public FamilyContactsController(IMediator mediator)
    {
        _mediator = mediator;
    }

    [HttpGet]
    public async Task<IActionResult> List(CancellationToken ct)
    {
        var result = await _mediator.Send(new ListFamilyContactsQuery(), ct);
        return result.ToActionResult(this);
    }

    [HttpPost]
    public async Task<IActionResult> Create([FromBody] FamilyContactUpsertRequest request, CancellationToken ct)
    {
        var result = await _mediator.Send(new CreateFamilyContactCommand(
            request.FullName, request.PhoneNumber, request.Note), ct);
        return result.ToActionResult(this,
            contact => Created($"/api/v1/family-contacts/{contact.Id}", contact));
    }

    [HttpPut("{id:guid}")]
    public async Task<IActionResult> Update(Guid id, [FromBody] FamilyContactUpsertRequest request, CancellationToken ct)
    {
        var result = await _mediator.Send(new UpdateFamilyContactCommand(id,
            request.FullName, request.PhoneNumber, request.Note), ct);
        return result.ToActionResult(this);
    }

    [HttpDelete("{id:guid}")]
    public async Task<IActionResult> Delete(Guid id, CancellationToken ct)
    {
        var result = await _mediator.Send(new DeleteFamilyContactCommand(id), ct);
        return result.ToActionResult(this, _ => NoContent());
    }

}
