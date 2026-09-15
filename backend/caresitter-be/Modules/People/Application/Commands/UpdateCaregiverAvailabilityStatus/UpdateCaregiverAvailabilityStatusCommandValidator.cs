using FluentValidation;

namespace CareSitter.Modules.People.Application.Commands.UpdateCaregiverAvailabilityStatus;

public sealed class UpdateCaregiverAvailabilityStatusCommandValidator
    : AbstractValidator<UpdateCaregiverAvailabilityStatusCommand>;
