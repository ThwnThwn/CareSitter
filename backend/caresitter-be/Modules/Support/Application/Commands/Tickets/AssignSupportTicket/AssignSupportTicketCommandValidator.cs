using FluentValidation;

namespace CareSitter.Modules.Support.Application.Commands.AssignSupportTicket;

public sealed class AssignSupportTicketCommandValidator
    : AbstractValidator<AssignSupportTicketCommand>;
