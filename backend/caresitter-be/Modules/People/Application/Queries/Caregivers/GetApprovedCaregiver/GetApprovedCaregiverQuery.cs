using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.People.Application;

public sealed record GetApprovedCaregiverQuery(Guid CaregiverId) : IRequest<CaregiverResponse?>;
