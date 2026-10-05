using CareSitter.Modules.Support.Application;
using CareSitter.Modules.Support.Application.Commands.CancelDispute;
using CareSitter.Modules.Support.Application.Commands.CreateDispute;
using CareSitter.Modules.Support.Application.Commands.ResolveDispute;

namespace CareSitter.Modules.Support.Controllers;

public sealed record CreateDisputeRequest(Guid BookingId, string? Reason = null,
    string? Description = null);
