using CareSitter.Modules.Support.Application;
using CareSitter.Modules.Support.Application.Commands.AssignSupportTicket;
using CareSitter.Modules.Support.Application.Commands.CreateSupportTicket;
using CareSitter.Modules.Support.Application.Commands.UpdateSupportTicketStatus;

namespace CareSitter.Modules.Support.Controllers;

public sealed record UpdateTicketStatusRequest(string Status, long? ExpectedVersion = null,
    string? Reason = null);
