using CareSitter.Modules.People.Application;
using MediatR;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace CareSitter.Modules.People.Controllers;

/// <summary>Cung cấp API tìm kiếm và xem caregiver đã được duyệt KYC.</summary>
[ApiController]
[Authorize]
[Route("api/v1/caregivers")]
public sealed class CaregiversController : ControllerBase
{
    private readonly IMediator _mediator;

    public CaregiversController(IMediator mediator)
    {
        _mediator = mediator;
    }

    [HttpGet]
    [AllowAnonymous]
    public async Task<IActionResult> List(
        double? lat, double? lng,
        string? city, string? district, string? skill,
        decimal? minRating, string? availabilityStatus,
        DateTimeOffset? start, DateTimeOffset? end,
        int page = 1, int pageSize = 20, CancellationToken ct = default)
    {
        var result = await _mediator.Send(new SearchCaregiversQuery(
            lat, lng, city, district, skill, minRating, availabilityStatus,
            start, end, page, pageSize), ct);
        return Ok(result);
    }

    [HttpGet("{id:guid}")]
    [AllowAnonymous]
    public async Task<IActionResult> Get(Guid id, CancellationToken ct)
    {
        var result = await _mediator.Send(new GetApprovedCaregiverQuery(id), ct);
        return result is null ? NotFound() : Ok(result);
    }
}
