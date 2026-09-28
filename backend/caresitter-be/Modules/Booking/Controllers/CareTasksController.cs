using CareSitter.Modules.Booking.Application;
using MediatR;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;

namespace CareSitter.Modules.Booking.Controllers;

/// <summary>Quản lý checklist chăm sóc của một booking.</summary>
[ApiController]
[Authorize]
[Route("api/v1/bookings/{id:guid}/tasks")]
public sealed class CareTasksController(ISender sender) : ControllerBase
{
    [HttpGet]
    public async Task<IActionResult> List(Guid id, CancellationToken ct)
    {
        var result = await sender.Send(new ListCareTasksQuery(id), ct);
        return result.ToActionResult(this);
    }

    [HttpPost]
    [Authorize(Roles = "CAREGIVER")]
    public async Task<IActionResult> Create(
        Guid id, [FromBody] CreateCareTaskRequest request, CancellationToken ct)
    {
        var result = await sender.Send(
            new CreateCareTaskCommand(id, request.Name, request.Description), ct);
        return result.ToActionResult(this, value => Created(
            $"/api/v1/bookings/{id}/tasks/{value.Id}", value));
    }

    [HttpPatch("{taskId:guid}/complete")]
    [HttpPut("{taskId:guid}/complete")]
    [Authorize(Roles = "CAREGIVER")]
    public async Task<IActionResult> CompleteTask(
        Guid id, Guid taskId, CancellationToken ct)
    {
        var result = await sender.Send(new CompleteCareTaskCommand(id, taskId), ct);
        return result.ToActionResult(this);
    }

    [HttpPost("{taskId:guid}/photos")]
    [Authorize(Roles = "CAREGIVER")]
    [RequestSizeLimit(10 * 1024 * 1024)]
    public async Task<IActionResult> UploadPhoto(
        Guid id, Guid taskId, IFormFile? file, CancellationToken ct)
    {
        if (file is null)
            return BadRequest(new { error = "Vui lòng chọn một ảnh." });

        await using var stream = file.OpenReadStream();
        var result = await sender.Send(new UploadCareTaskPhotoCommand(
            id, taskId, stream, file.FileName, file.ContentType, file.Length), ct);
        return result.ToActionResult(this);
    }

    [HttpPatch("{taskId:guid}/skip")]
    [HttpPut("{taskId:guid}/skip")]
    [Authorize(Roles = "CAREGIVER")]
    public async Task<IActionResult> SkipTask(
        Guid id, Guid taskId, [FromBody] SkipCareTaskRequest request, CancellationToken ct)
    {
        var result = await sender.Send(
            new SkipCareTaskCommand(id, taskId, request.SkipReason), ct);
        return result.ToActionResult(this);
    }
}

public sealed record CreateCareTaskRequest(
    string Name, string? Description = null,
    bool IsRequired = false, bool RequiresPhoto = false, int SortOrder = 0);
public sealed record SkipCareTaskRequest(string SkipReason);
