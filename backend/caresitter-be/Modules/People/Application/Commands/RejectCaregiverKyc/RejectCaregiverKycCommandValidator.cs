using FluentValidation;

namespace CareSitter.Modules.People.Application.Commands.RejectCaregiverKyc;

public sealed class RejectCaregiverKycCommandValidator
    : AbstractValidator<RejectCaregiverKycCommand>;
