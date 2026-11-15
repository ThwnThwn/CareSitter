using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Booking.Application;

public sealed record SetChecklistTemplateActiveCommand(
    Guid ServiceTypeId, Guid TemplateId, bool IsActive)
    : IRequest<Result<ChecklistTemplateResponse>>;
