using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Booking.Application;

public sealed record DeleteChecklistTemplateCommand(Guid ServiceTypeId, Guid TemplateId)
    : IRequest<Result>;
