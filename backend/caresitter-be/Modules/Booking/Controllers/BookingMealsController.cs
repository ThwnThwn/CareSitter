using CareSitter.Modules.Booking.Application;
using MediatR;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace CareSitter.Modules.Booking.Controllers;

[ApiController, Authorize, RequestSizeLimit(8192)]
[ResponseCache(NoStore = true, Location = ResponseCacheLocation.None)]
[Route("api/v1/bookings/{bookingId:guid}/meals")]
public sealed class BookingMealsController(IMediator mediator) : ControllerBase
{
    [HttpGet, Authorize(Roles = "CUSTOMER,CAREGIVER")]
    public async Task<IActionResult> List(Guid bookingId, CancellationToken ct) =>
        (await mediator.Send(new ListBookingMealsQuery(bookingId), ct)).ToActionResult(this);

    [HttpPut("plan"), Authorize(Roles = "CUSTOMER")]
    public async Task<IActionResult> Share(Guid bookingId, ShareMealPlanRequest request, CancellationToken ct) =>
        (await mediator.Send(new ShareBookingMealPlanCommand(bookingId, request.PlanId), ct)).ToActionResult(this);

    [HttpDelete("plan/{plannedDate}"), Authorize(Roles = "CUSTOMER")]
    public async Task<IActionResult> Revoke(Guid bookingId, DateOnly plannedDate, CancellationToken ct) =>
        (await mediator.Send(new RevokeBookingMealPlanCommand(bookingId, plannedDate), ct)).ToActionResult(this);

    [HttpPost("records"), Authorize(Roles = "CAREGIVER")]
    public async Task<IActionResult> Record(Guid bookingId, RecordMealRequest request,
        [FromHeader(Name = "Idempotency-Key")] Guid key, CancellationToken ct) =>
        (await mediator.Send(new RecordBookingMealCommand(bookingId, request.PlanId, request.RecipeVersionId,
            request.MealType, request.Outcome, request.Note, key), ct)).ToActionResult(this);

    [HttpPost("records/{recordId:guid}/corrections"), Authorize(Roles = "CAREGIVER")]
    public async Task<IActionResult> Correct(Guid bookingId, Guid recordId, CorrectMealRequest request,
        [FromHeader(Name = "Idempotency-Key")] Guid key, CancellationToken ct) =>
        (await mediator.Send(new CorrectBookingMealCommand(bookingId, recordId, request.Outcome,
            request.Note, request.Reason, request.ExpectedRevision, key), ct)).ToActionResult(this);

}
