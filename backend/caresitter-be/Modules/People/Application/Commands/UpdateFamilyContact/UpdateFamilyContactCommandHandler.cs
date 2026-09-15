using CareSitter.Infrastructure.Security;
using CareSitter.Modules.People.Domain;
using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.People.Application.Commands.UpdateFamilyContact;

internal sealed class UpdateFamilyContactCommandHandler(
    IPeopleRepository repository,
    ICurrentUser currentUser)
    : IRequestHandler<UpdateFamilyContactCommand, Result<FamilyContactResponse>>
{
    public async Task<Result<FamilyContactResponse>> Handle(
        UpdateFamilyContactCommand request, CancellationToken ct)
    {
        if (currentUser.UserId is not { } userId) return PeopleErrors.Unauthenticated();
        await using var tx = await repository.BeginUserScopeAsync(userId, ct);
        var contact = await repository.GetFamilyContactAsync(request.ContactId, userId, ct);
        if (contact is null) return PeopleErrors.NotFound();
        var updated = contact.Update(request.FullName, request.PhoneNumber, request.Note);
        if (updated.IsFailure) return updated.Error;
        var duplicate = await repository.FamilyPhoneExistsAsync(userId,
            contact.PhoneNumber, request.ContactId, ct);
        if (duplicate) return PeopleErrors.FamilyPhoneExists();
        await repository.SaveChangesAsync(ct);
        await tx.CommitAsync(ct);
        return PeopleResponseMapper.ToResponse(contact);
    }
}
