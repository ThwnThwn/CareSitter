using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.People.Application.Commands.SelfBeneficiary;

public sealed record LinkSelfBeneficiaryCommand(Guid BeneficiaryId) : IRequest<Result<BeneficiaryResponse>>;
