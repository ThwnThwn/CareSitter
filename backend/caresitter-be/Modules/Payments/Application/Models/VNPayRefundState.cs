using System.Globalization;
using System.Net;
using CareSitter.Modules.Payments.Domain;
using CareSitter.SharedKernel.Results;

namespace CareSitter.Modules.Payments.Application.Refunds;

public enum VNPayRefundState { Confirmed, Processing, Rejected, Unknown }
