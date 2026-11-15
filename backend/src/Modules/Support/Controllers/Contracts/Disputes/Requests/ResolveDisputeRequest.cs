using CareSitter.Modules.Support.Application;
using CareSitter.Modules.Support.Application.Commands.CancelDispute;
using CareSitter.Modules.Support.Application.Commands.CreateDispute;
using CareSitter.Modules.Support.Application.Commands.ResolveDispute;

namespace CareSitter.Modules.Support.Controllers;

public sealed record ResolveDisputeRequest(string Decision, long? RefundAmount = null,
    long? CaregiverPenaltyAmount = null);
