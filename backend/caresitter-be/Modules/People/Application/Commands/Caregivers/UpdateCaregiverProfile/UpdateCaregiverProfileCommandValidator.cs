using FluentValidation;

namespace CareSitter.Modules.People.Application.Commands.UpdateCaregiverProfile;

public sealed class UpdateCaregiverProfileCommandValidator
    : AbstractValidator<UpdateCaregiverProfileCommand>;
