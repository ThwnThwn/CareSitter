using FluentValidation;

namespace CareSitter.Modules.People.Application.Commands.CreateCaregiverProfile;

public sealed class CreateCaregiverProfileCommandValidator
    : AbstractValidator<CreateCaregiverProfileCommand>;
