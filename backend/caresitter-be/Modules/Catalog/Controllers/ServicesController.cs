using CareSitter.Contracts.Services;
using CareSitter.Modules.Catalog.Application;
using CareSitter.Modules.Catalog.Application.Commands.QuoteService;
using MediatR;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;

namespace CareSitter.Modules.Catalog.Controllers;

/// <summary>
/// Quản lý danh mục dịch vụ hỗ trợ chăm sóc phi y tế.
/// Cho phép liệt kê, xem chi tiết và báo giá theo khung giờ đặt lịch.
/// </summary>
[ApiController]
[Route("api/v1/services")]
public sealed class ServicesController : ControllerBase
{
    private readonly IMediator _mediator;
    private readonly IServiceChecklistReader _checklistReader;

    public ServicesController(IMediator mediator, IServiceChecklistReader checklistReader)
    {
        _mediator = mediator;
        _checklistReader = checklistReader;
    }

    /// <summary>Lấy dịch vụ đang hoạt động, sắp xếp theo thời lượng gợi ý rồi theo tên.</summary>
    [HttpGet]
    [ProducesResponseType(StatusCodes.Status200OK)]
    public async Task<IActionResult> List(CancellationToken ct)
    {
        return Ok(await _mediator.Send(new ListActiveServicesQuery(), ct));
    }

    /// <summary>Xem chi tiết một dịch vụ theo ID. Trả về 404 nếu không tồn tại hoặc đã vô hiệu hóa.</summary>
    [HttpGet("{id:guid}")]
    [ProducesResponseType(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> Get(Guid id, CancellationToken ct)
    {
        var item = await _mediator.Send(new GetActiveServiceQuery(id), ct);
        return item is null ? NotFound() : Ok(item);
    }

    /// <summary>Lấy checklist đang hoạt động của một dịch vụ công khai.</summary>
    [HttpGet("{id:guid}/checklist-templates")]
    [ProducesResponseType(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> ListChecklist(Guid id, CancellationToken ct)
    {
        var service = await _mediator.Send(new GetActiveServiceQuery(id), ct);
        if (service is null) return NotFound();
        return Ok(await _checklistReader.ListActiveAsync(id, ct));
    }

    /// <summary>
    /// Tính giá dự kiến cho dịch vụ theo khung giờ (ScheduledStart → ScheduledEnd).
    /// Yêu cầu xác thực. Dùng trước bước xác nhận đặt lịch.
    /// </summary>
    [HttpPost("{id:guid}/quote")]
    [Microsoft.AspNetCore.Authorization.Authorize]
    [ProducesResponseType(StatusCodes.Status200OK)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status400BadRequest)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status404NotFound)]
    public async Task<IActionResult> Quote(Guid id, [FromBody] QuoteRequest request, CancellationToken ct)
    {
        var result = await _mediator.Send(new QuoteServiceCommand(id,
            request.ScheduledStart, request.ScheduledEnd), ct);
        return result.ToActionResult(this);
    }
}
