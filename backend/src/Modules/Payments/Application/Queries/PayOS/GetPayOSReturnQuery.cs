using MediatR;

namespace CareSitter.Modules.Payments.Application;

public sealed record GetPayOSReturnQuery(string? OrderCode) : IRequest<string>;
internal sealed class GetPayOSReturnQueryHandler(IPayOSPaymentPortal portal)
    : IRequestHandler<GetPayOSReturnQuery, string>
{
    public Task<string> Handle(GetPayOSReturnQuery request, CancellationToken ct) =>
        portal.GetReturnUrlAsync(request.OrderCode, ct);
}
