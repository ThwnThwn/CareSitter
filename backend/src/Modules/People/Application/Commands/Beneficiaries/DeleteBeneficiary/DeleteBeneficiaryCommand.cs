using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.People.Application.Commands.DeleteBeneficiary;

public sealed record DeleteBeneficiaryCommand(Guid BeneficiaryId) : IRequest<Result<Unit>>;
