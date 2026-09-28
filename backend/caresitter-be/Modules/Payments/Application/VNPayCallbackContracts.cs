using MediatR;

namespace CareSitter.Modules.Payments.Application;

public sealed record ProcessVnPayIpnCommand(IReadOnlyDictionary<string, string> Values)
    : IRequest<VnPayIpnResult>;
public sealed record ProcessVnPayReturnCommand(IReadOnlyDictionary<string, string> Values)
    : IRequest<VnPayReturnResult>;
public sealed record VnPayIpnResult(string Code, string Message);
public sealed record VnPayReturnResult(string RedirectUrl);

public interface IVnPayCallbackProcessor
{
    Task<VnPayIpnResult> ProcessIpnAsync(
        IReadOnlyDictionary<string, string> values, CancellationToken ct = default);
    Task<VnPayReturnResult> ProcessReturnAsync(
        IReadOnlyDictionary<string, string> values, CancellationToken ct = default);
}

internal sealed class ProcessVnPayIpnCommandHandler(IVnPayCallbackProcessor processor)
    : IRequestHandler<ProcessVnPayIpnCommand, VnPayIpnResult>
{
    public Task<VnPayIpnResult> Handle(ProcessVnPayIpnCommand request, CancellationToken ct) =>
        processor.ProcessIpnAsync(request.Values, ct);
}

internal sealed class ProcessVnPayReturnCommandHandler(IVnPayCallbackProcessor processor)
    : IRequestHandler<ProcessVnPayReturnCommand, VnPayReturnResult>
{
    public Task<VnPayReturnResult> Handle(ProcessVnPayReturnCommand request, CancellationToken ct) =>
        processor.ProcessReturnAsync(request.Values, ct);
}
