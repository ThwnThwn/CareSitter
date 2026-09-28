using CareSitter.Contracts.Services;
using CareSitter.Modules.People.Domain;
using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.People.Application.Commands.CreateFamilyContact;

internal sealed class CreateFamilyContactCommandHandler(
    IPeopleRepository repository,
    ICurrentUser currentUser)
    : IRequestHandler<CreateFamilyContactCommand, Result<FamilyContactResponse>>
{
    public async Task<Result<FamilyContactResponse>> Handle(
        CreateFamilyContactCommand request, CancellationToken ct)
    {
        if (currentUser.UserId is not { } userId) return PeopleErrors.Unauthenticated();
        var contact = FamilyContact.Create(userId, request.FullName,
            request.PhoneNumber, request.Note);
        if (contact.IsFailure) return contact.Error;

        await using var tx = await repository.BeginUserScopeAsync(userId, ct);
        var duplicate = await repository.FamilyPhoneExistsAsync(userId,
            contact.Value.PhoneNumber, null, ct);
        if (duplicate) return PeopleErrors.FamilyPhoneExists();

        repository.AddFamilyContact(contact.Value);
        await repository.SaveChangesAsync(ct);
        await tx.CommitAsync(ct);
        return PeopleResponseMapper.ToResponse(contact.Value);
    }
}
