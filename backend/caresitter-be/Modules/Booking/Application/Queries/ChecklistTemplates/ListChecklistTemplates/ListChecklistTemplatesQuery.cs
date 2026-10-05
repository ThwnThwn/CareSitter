using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Booking.Application;

public sealed record ListChecklistTemplatesQuery(Guid ServiceTypeId)
    : IRequest<Result<IReadOnlyList<ChecklistTemplateResponse>>>;
