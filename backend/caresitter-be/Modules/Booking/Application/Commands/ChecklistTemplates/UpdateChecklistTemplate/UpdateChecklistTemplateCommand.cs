using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Booking.Application;

public sealed record UpdateChecklistTemplateCommand(
    Guid ServiceTypeId, Guid TemplateId, ChecklistTemplateInput Input)
    : IRequest<Result<ChecklistTemplateResponse>>;
