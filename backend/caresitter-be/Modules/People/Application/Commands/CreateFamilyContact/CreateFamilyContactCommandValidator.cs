using FluentValidation;

namespace CareSitter.Modules.People.Application.Commands.CreateFamilyContact;

public sealed class CreateFamilyContactCommandValidator
    : AbstractValidator<CreateFamilyContactCommand>;
