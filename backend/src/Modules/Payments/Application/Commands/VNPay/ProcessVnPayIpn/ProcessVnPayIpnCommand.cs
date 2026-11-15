using MediatR;

namespace CareSitter.Modules.Payments.Application;

public sealed record ProcessVnPayIpnCommand(IReadOnlyDictionary<string, string> Values)
    : IRequest<VnPayIpnResult>;
