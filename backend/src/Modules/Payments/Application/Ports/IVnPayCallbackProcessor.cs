using MediatR;

namespace CareSitter.Modules.Payments.Application;

public interface IVnPayCallbackProcessor
{
    Task<VnPayIpnResult> ProcessIpnAsync(
        IReadOnlyDictionary<string, string> values, CancellationToken ct = default);
    Task<VnPayReturnResult> ProcessReturnAsync(
        IReadOnlyDictionary<string, string> values, CancellationToken ct = default);
}
