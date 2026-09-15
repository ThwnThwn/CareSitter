using FluentValidation;

namespace CareSitter.Modules.Support.Application.Commands.UpdateSupportTicketStatus;

public sealed class UpdateSupportTicketStatusCommandValidator
    : AbstractValidator<UpdateSupportTicketStatusCommand>;
