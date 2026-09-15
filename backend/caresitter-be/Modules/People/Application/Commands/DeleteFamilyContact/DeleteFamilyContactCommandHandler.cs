using CareSitter.Infrastructure.Security;
using CareSitter.Modules.People.Domain;
using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.People.Application.Commands.DeleteFamilyContact;

internal sealed class DeleteFamilyContactCommandHandler(
    IPeopleRepository repository,
    ICurrentUser currentUser) : IRequestHandler<DeleteFamilyContactCommand, Result<Unit>>
{
    public async Task<Result<Unit>> Handle(DeleteFamilyContactCommand request, CancellationToken ct)
    {
        if (currentUser.UserId is not { } userId) return PeopleErrors.Unauthenticated();
        await using var tx = await repository.BeginUserScopeAsync(userId, ct);
        var contact = await repository.GetFamilyContactAsync(request.ContactId, userId, ct);
        if (contact is null) return PeopleErrors.NotFound();
        contact.Delete(DateTimeOffset.UtcNow);
        await repository.SaveChangesAsync(ct);
        await tx.CommitAsync(ct);
        return Unit.Value;
    }
}
