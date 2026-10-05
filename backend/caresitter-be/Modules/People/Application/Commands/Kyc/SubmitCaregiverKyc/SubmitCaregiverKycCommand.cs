using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.People.Application.Commands.SubmitCaregiverKyc;

public sealed record SubmitCaregiverKycCommand(string? CccdNumber,
    Guid CccdFrontMediaId, Guid CccdBackMediaId, Guid[]? CertificateMediaIds)
    : IRequest<Result<CaregiverKycSubmissionResponse>>;
