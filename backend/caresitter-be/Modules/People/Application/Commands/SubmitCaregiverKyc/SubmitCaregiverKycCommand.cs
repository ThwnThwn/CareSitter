using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.People.Application.Commands.SubmitCaregiverKyc;

public sealed record SubmitCaregiverKycCommand(string? CccdNumber,
    string? CccdFrontUrl, string? CccdBackUrl, string[]? CertificateUrls)
    : IRequest<Result<CaregiverKycSubmissionResponse>>;
