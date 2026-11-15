using CareSitter.Modules.People.Application;
using MediatR;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace CareSitter.Modules.People.Controllers;

[ApiController, Authorize(Roles = "CUSTOMER"), RequestSizeLimit(4096)]
[ResponseCache(NoStore = true, Location = ResponseCacheLocation.None)]
[Route("api/v1/beneficiaries/{beneficiaryId:guid}/meal-feedback")]
public sealed class MealTasteFeedbackController(IMediator mediator) : ControllerBase
{
    [HttpGet]
    public async Task<IActionResult> List(Guid beneficiaryId, [FromQuery] Guid planId, CancellationToken ct) =>
        (await mediator.Send(new ListMealTasteFeedbackQuery(beneficiaryId, planId), ct)).ToActionResult(this);
    [HttpPost]
    public async Task<IActionResult> Submit(Guid beneficiaryId, SubmitMealTasteFeedbackRequest request,
        [FromHeader(Name = "Idempotency-Key")] Guid key, CancellationToken ct) =>
        (await mediator.Send(new SubmitMealTasteFeedbackCommand(beneficiaryId, request.PlanId,
            request.RecipeVersionId, request.Feedback, key), ct)).ToActionResult(this);
    [HttpPut("{feedbackId:guid}/review")]
    public async Task<IActionResult> Review(Guid beneficiaryId, Guid feedbackId, ReviewMealTasteFeedbackRequest request, CancellationToken ct) =>
        (await mediator.Send(new ReviewMealTasteFeedbackCommand(beneficiaryId, feedbackId,
            request.Approve, request.ExpectedHealthRevision), ct)).ToActionResult(this);
}
