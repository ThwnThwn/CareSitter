using FluentValidation;

namespace CareSitter.Modules.People.Application.Commands.DeleteFamilyContact;

public sealed class DeleteFamilyContactCommandValidator
    : AbstractValidator<DeleteFamilyContactCommand>;
