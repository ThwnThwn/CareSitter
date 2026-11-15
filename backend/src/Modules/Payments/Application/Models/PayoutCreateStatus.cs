using CareSitter.Modules.Payments.Domain;
using CareSitter.SharedKernel.Results;

namespace CareSitter.Modules.Payments.Application.Payouts;

internal enum PayoutCreateStatus { Created, InsufficientBalance, ConcurrentDuplicate }
