namespace CareSitter.Modules.Support.Controllers.Contracts.Notifications;

public sealed record PushCheckpointRequest(Guid EventId, Guid ClaimToken, string[] Keys);
