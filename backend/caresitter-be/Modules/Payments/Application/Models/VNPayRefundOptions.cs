using System.Globalization;
using System.Net;
using CareSitter.Modules.Payments.Domain;
using CareSitter.SharedKernel.Results;

namespace CareSitter.Modules.Payments.Application.Refunds;

public sealed class VNPayRefundOptions
{
    public const string SectionName = "Payments:VNPayRefund";
    // Opt-in only. Registering the adapter must not enable money movement.
    public bool Enabled { get; set; }
    public string ApiUrl { get; set; } = string.Empty;
    public string ServerIpAddress { get; set; } = "127.0.0.1";
    public int PollIntervalSeconds { get; set; } = 10;
    public int RetryDelaySeconds { get; set; } = 30;
    public int LeaseSeconds { get; set; } = 30;
    public int BatchSize { get; set; } = 10;

    public static bool HasValidWorkerSettings(VNPayRefundOptions options) =>
        options.PollIntervalSeconds is >= 5 and <= 300 &&
        options.RetryDelaySeconds is >= 10 and <= 3600 &&
        options.LeaseSeconds is >= 10 and <= 300 &&
        options.BatchSize is >= 1 and <= 100 &&
        IPAddress.TryParse(options.ServerIpAddress, out _);
}
