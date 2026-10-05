using MediatR;

namespace CareSitter.Modules.Payments.Application;

internal sealed class ProcessVnPayIpnCommandHandler(IVnPayCallbackProcessor processor)
    : IRequestHandler<ProcessVnPayIpnCommand, VnPayIpnResult>
{
    public Task<VnPayIpnResult> Handle(ProcessVnPayIpnCommand request, CancellationToken ct) =>
        processor.ProcessIpnAsync(request.Values, ct);
}
