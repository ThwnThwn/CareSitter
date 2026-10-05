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
}
