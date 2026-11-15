using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.People.Application.Commands.ApproveCaregiverKyc;

public sealed record ApproveCaregiverKycCommand(Guid CaregiverId)
    : IRequest<Result<CaregiverKycApprovalResponse>>;
