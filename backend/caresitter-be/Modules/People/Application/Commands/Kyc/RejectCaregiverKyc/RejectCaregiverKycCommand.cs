using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.People.Application.Commands.RejectCaregiverKyc;

public sealed record RejectCaregiverKycCommand(Guid CaregiverId, string? Reason)
    : IRequest<Result<CaregiverKycRejectionResponse>>;
