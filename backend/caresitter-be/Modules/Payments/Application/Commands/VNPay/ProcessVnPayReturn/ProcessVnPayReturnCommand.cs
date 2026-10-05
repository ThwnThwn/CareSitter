using MediatR;

namespace CareSitter.Modules.Payments.Application;

public sealed record ProcessVnPayReturnCommand(IReadOnlyDictionary<string, string> Values)
    : IRequest<VnPayReturnResult>;
