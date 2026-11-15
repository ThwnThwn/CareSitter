using CareSitter.Modules.Support.Application;
using CareSitter.Modules.Support.Application.Commands.AssignSupportTicket;
using CareSitter.Modules.Support.Application.Commands.CreateSupportTicket;
using CareSitter.Modules.Support.Application.Commands.UpdateSupportTicketStatus;

namespace CareSitter.Modules.Support.Controllers;

public sealed record CreateTicketRequest(
    string Type,
    string Title,
    string Description,
    string? Priority = "MEDIUM",
    Guid? BookingId = null,
    string[]? AttachmentUrls = null);
