using FluentValidation;

namespace CareSitter.Modules.People.Application.Commands.ApproveCaregiverKyc;

public sealed class ApproveCaregiverKycCommandValidator
    : AbstractValidator<ApproveCaregiverKycCommand>;
