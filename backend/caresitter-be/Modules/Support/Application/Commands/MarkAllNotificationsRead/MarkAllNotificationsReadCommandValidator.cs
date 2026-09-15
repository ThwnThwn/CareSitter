using FluentValidation;

namespace CareSitter.Modules.Support.Application.Commands.MarkAllNotificationsRead;

public sealed class MarkAllNotificationsReadCommandValidator
    : AbstractValidator<MarkAllNotificationsReadCommand>;
