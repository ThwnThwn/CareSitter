using FluentValidation;

namespace CareSitter.Modules.Support.Application.Commands.MarkNotificationRead;

public sealed class MarkNotificationReadCommandValidator
    : AbstractValidator<MarkNotificationReadCommand>;
