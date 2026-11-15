using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Booking.Application;

public sealed record CreateChecklistTemplateCommand(Guid ServiceTypeId, ChecklistTemplateInput Input)
    : IRequest<Result<ChecklistTemplateResponse>>;
