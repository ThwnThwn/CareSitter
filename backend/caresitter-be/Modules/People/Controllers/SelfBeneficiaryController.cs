using CareSitter.Modules.People.Application.Commands.SelfBeneficiary;
using MediatR;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace CareSitter.Modules.People.Controllers;

[ApiController]
[Authorize(Roles = "CUSTOMER")]
[Route("api/v1/beneficiaries/self")]
public sealed class SelfBeneficiaryController(IMediator mediator) : ControllerBase
{
    [HttpGet]
    public async Task<IActionResult> Get(CancellationToken ct) =>
        (await mediator.Send(new GetSelfBeneficiaryQuery(), ct)).ToActionResult(this);

    [HttpPost]
    public async Task<IActionResult> Create([FromBody] SelfBeneficiaryRequest request, CancellationToken ct)
    {
        var result = await mediator.Send(new CreateSelfBeneficiaryCommand(request.FullName,
            request.DateOfBirth, request.Gender, request.Phone, request.AvatarUrl,
            request.DefaultAddressId, request.CareLevel, request.GeneralNote,
            request.CareInstructions, request.EmergencyContacts), ct);
        return result.ToActionResult(this, value => value.Created
            ? Created($"/api/v1/beneficiaries/{value.Beneficiary.Id}", value.Beneficiary)
            : Ok(value.Beneficiary));
    }

    [HttpPut("link")]
    public async Task<IActionResult> Link([FromBody] LinkSelfBeneficiaryRequest request, CancellationToken ct) =>
        (await mediator.Send(new LinkSelfBeneficiaryCommand(request.BeneficiaryId), ct)).ToActionResult(this);
}
