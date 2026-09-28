using CareSitter.Contracts.Services;
using CareSitter.Modules.People.Domain;
using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.People.Application.Commands.DeleteBeneficiary;

internal sealed class DeleteBeneficiaryCommandHandler(
    IPeopleRepository repository,
    ICurrentUser currentUser) : IRequestHandler<DeleteBeneficiaryCommand, Result<Unit>>
{
    public async Task<Result<Unit>> Handle(DeleteBeneficiaryCommand request, CancellationToken ct)
    {
        if (currentUser.UserId is not { } userId) return PeopleErrors.Unauthenticated();
        await using var tx = await repository.BeginUserScopeAsync(userId, ct);
        var entity = await repository.GetBeneficiaryAsync(request.BeneficiaryId, userId, ct);
        if (entity is null) return PeopleErrors.NotFound();
        entity.Delete(DateTimeOffset.UtcNow);
        await repository.SaveChangesAsync(ct);
        await tx.CommitAsync(ct);
        return Unit.Value;
    }
}
