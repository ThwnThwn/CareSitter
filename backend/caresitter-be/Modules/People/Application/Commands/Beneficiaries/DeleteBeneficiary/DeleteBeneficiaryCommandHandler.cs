using CareSitter.Contracts.Services;
using CareSitter.Modules.People.Domain;
using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.People.Application.Commands.DeleteBeneficiary;

internal sealed class DeleteBeneficiaryCommandHandler(
    IPeopleRepository repository,
    ICurrentUser currentUser,
    IBeneficiaryDeletionEventWriter deletionEvents) : IRequestHandler<DeleteBeneficiaryCommand, Result<Unit>>
{
    public async Task<Result<Unit>> Handle(DeleteBeneficiaryCommand request, CancellationToken ct)
    {
        if (currentUser.UserId is not { } userId) return PeopleErrors.Unauthenticated();
        await using var tx = await repository.BeginUserScopeAsync(userId, ct);
        var entity = await repository.GetBeneficiaryAsync(request.BeneficiaryId, userId, ct);
        if (entity is null) return PeopleErrors.NotFound();
        var deletedAt = DateTimeOffset.UtcNow;
        var deleted = entity.Delete(deletedAt);
        if (deleted.IsFailure) return deleted.Error;
        // The event and soft deletion commit together; the relay may retry safely.
        deletionEvents.Stage(userId, entity.Id, deletedAt);
        await repository.SaveChangesAsync(ct);
        await tx.CommitAsync(ct);
        return Unit.Value;
    }
}
