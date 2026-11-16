using MediatR;

namespace CareSitter.Modules.Payments.Application;

public sealed record ProcessPayOSReturnCommand(string? OrderCode) : IRequest<string>;
internal sealed class ProcessPayOSReturnCommandHandler(IPayOSPaymentPortal portal)
    : IRequestHandler<ProcessPayOSReturnCommand, string>
{
    // The return flow can reconcile a pending intent with PayOS before redirecting.
    public Task<string> Handle(ProcessPayOSReturnCommand request, CancellationToken ct) =>
        portal.GetReturnUrlAsync(request.OrderCode, ct);
}
