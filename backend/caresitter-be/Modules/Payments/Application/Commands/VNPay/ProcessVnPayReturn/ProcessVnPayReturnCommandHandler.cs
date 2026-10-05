using MediatR;

namespace CareSitter.Modules.Payments.Application;

internal sealed class ProcessVnPayReturnCommandHandler(IVnPayCallbackProcessor processor)
    : IRequestHandler<ProcessVnPayReturnCommand, VnPayReturnResult>
{
    public Task<VnPayReturnResult> Handle(ProcessVnPayReturnCommand request, CancellationToken ct) =>
        processor.ProcessReturnAsync(request.Values, ct);
}
