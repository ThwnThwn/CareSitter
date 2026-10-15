using CareSitter.Contracts.Services;
using CareSitter.Modules.Support.Application.Chat;
using CareSitter.SharedKernel.Results;
using CareSitter.Modules.Support.Controllers.Contracts;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Configuration;
using Microsoft.AspNetCore.RateLimiting;

namespace CareSitter.Modules.Support.Controllers;

[ApiController]
[Authorize]
[Route("api/v1/support")]
public sealed class SupportChatController(ISupportChatService chat, ICurrentUser currentUser) : ControllerBase
{
    [HttpGet("chat-config")]
    public IActionResult Config([FromServices] IConfiguration config) => Ok(new
    {
        enabled = config.GetValue<bool>("SupportChat:Enabled"),
        pushEnabled = config.GetValue<bool>("SupportChat:PushEnabled"),
        messageMaxLength = 2000,
        reconcileSeconds = 15
    });

    [HttpPost("conversations")]
    [Authorize(Roles = "CUSTOMER,CAREGIVER")]
    [EnableRateLimiting("support-chat-write")]
    public async Task<IActionResult> Create([FromHeader(Name = "Idempotency-Key")] Guid key,
        [FromBody] ChatCreateRequest request, CancellationToken ct)
    {
        var actor = Actor();
        if (actor is null) return Unauthorized();
        var result = await chat.CreateAsync(actor, key, request, ct);
        return Map(result, value => value.Replayed ? Ok(value) :
            Created($"/api/v1/support/conversations/{value.Conversation.Id}", value));
    }

    [HttpGet("conversations")]
    public async Task<IActionResult> List([FromQuery] DateTimeOffset? beforeCreatedAt,
        [FromQuery] Guid? beforeId, [FromQuery] int limit = 20, CancellationToken ct = default)
    {
        var actor = Actor();
        return actor is null ? Unauthorized() : Map(await chat.ListAsync(actor, null,
            beforeCreatedAt, beforeId, limit, ct));
    }

    [HttpGet("conversations/{id:guid}")]
    public async Task<IActionResult> Get(Guid id, CancellationToken ct)
    {
        var actor = Actor();
        return actor is null ? Unauthorized() : Map(await chat.GetAsync(actor, id, ct));
    }

    [HttpGet("conversations/{id:guid}/messages")]
    public async Task<IActionResult> Messages(Guid id, [FromQuery] long? beforeSequence,
        [FromQuery] long? afterSequence, [FromQuery] long? highWatermarkSequence,
        [FromQuery] int limit = 50, CancellationToken ct = default)
    {
        var actor = Actor();
        return actor is null ? Unauthorized() : Map(await chat.MessagesAsync(actor, id,
            beforeSequence, afterSequence, highWatermarkSequence, limit, ct));
    }

    [HttpGet("conversations/{id:guid}/activities")]
    public async Task<IActionResult> Activities(Guid id,
        [FromQuery] DateTimeOffset? beforeCreatedAt, [FromQuery] Guid? beforeId,
        [FromQuery] int limit = 50, CancellationToken ct = default)
    {
        var actor = Actor();
        return actor is null ? Unauthorized() : Map(await chat.ActivitiesAsync(actor, id,
            beforeCreatedAt, beforeId, limit, ct));
    }

    [HttpPost("conversations/{id:guid}/messages")]
    [EnableRateLimiting("support-chat-write")]
    public async Task<IActionResult> Send(Guid id, [FromHeader(Name = "Idempotency-Key")] Guid key,
        [FromBody] ChatSendRequest request, CancellationToken ct)
    {
        var actor = Actor();
        return actor is null ? Unauthorized() : Map(await chat.SendAsync(actor, id, key,
            request.Body, ct));
    }

    [HttpPut("conversations/{id:guid}/read")]
    public async Task<IActionResult> Read(Guid id, [FromBody] ChatReadRequest request,
        CancellationToken ct)
    {
        var actor = Actor();
        return actor is null ? Unauthorized() : Map(await chat.ReadAsync(actor, id,
            request.LastReadSequence, ct));
    }

    private ChatActor? Actor()
    {
        if (currentUser.UserId is not { } userId) return null;
        var isAdmin = currentUser.IsInRole("ADMIN");
        if (!isAdmin && !currentUser.IsInRole("CUSTOMER") &&
            !currentUser.IsInRole("CAREGIVER")) return null;
        var role = isAdmin ? "ADMIN" : currentUser.IsInRole("CAREGIVER") ? "CAREGIVER" : "CUSTOMER";
        return new ChatActor(userId, isAdmin, role);
    }

    internal static IActionResult Map<T>(Result<T> result, Func<T, IActionResult>? success = null)
    {
        if (result.IsSuccess) return success?.Invoke(result.Value) ?? new OkObjectResult(result.Value);
        var error = result.Error;
        var details = new ProblemDetails { Title = error.Code, Detail = error.Message };
        return error.Type switch
        {
            ErrorType.NotFound => new NotFoundObjectResult(details),
            ErrorType.Conflict => new ConflictObjectResult(details),
            ErrorType.Forbidden => new ObjectResult(details) { StatusCode = 403 },
            ErrorType.Unauthorized => new UnauthorizedObjectResult(details),
            ErrorType.Unavailable => new ObjectResult(details) { StatusCode = 503 },
            _ => new BadRequestObjectResult(details)
        };
    }
}
[ApiController]
[Authorize(Roles = "ADMIN")]
[Route("api/v1/admin/support/conversations")]
public sealed class AdminSupportChatController(ISupportChatService chat, ICurrentUser currentUser) : ControllerBase
{
    private ChatActor? Actor() => currentUser.UserId is { } id
        ? new ChatActor(id, true, "ADMIN") : null;

    [HttpGet]
    public async Task<IActionResult> Queue([FromQuery] string? queue,
        [FromQuery] DateTimeOffset? beforeCreatedAt, [FromQuery] Guid? beforeId,
        [FromQuery] int limit = 20, CancellationToken ct = default)
    {
        var actor = Actor();
        return actor is null ? Unauthorized() : SupportChatController.Map(await chat.ListAsync(actor,
            queue, beforeCreatedAt, beforeId, limit, ct));
    }

    [HttpPost("{id:guid}/claim")]
    public async Task<IActionResult> Claim(Guid id, [FromBody] ChatVersionRequest request,
        CancellationToken ct)
    {
        var actor = Actor();
        return actor is null ? Unauthorized() : SupportChatController.Map(await chat.ClaimAsync(actor,
            id, request.ExpectedVersion, ct));
    }

    [HttpPatch("{id:guid}/assignment")]
    public async Task<IActionResult> Transfer(Guid id, [FromBody] ChatTransferRequest request,
        CancellationToken ct)
    {
        var actor = Actor();
        return actor is null ? Unauthorized() : SupportChatController.Map(await chat.TransferAsync(actor,
            id, request.TargetAdminId, request.Takeover, request.ExpectedVersion,
            request.Reason, ct));
    }

    [HttpPatch("{id:guid}/status")]
    public async Task<IActionResult> Status(Guid id, [FromBody] ChatStatusRequest request,
        CancellationToken ct)
    {
        var actor = Actor();
        return actor is null ? Unauthorized() : SupportChatController.Map(await chat.StatusAsync(actor,
            id, request.Status, request.ExpectedVersion, request.Reason, ct));
    }
}
