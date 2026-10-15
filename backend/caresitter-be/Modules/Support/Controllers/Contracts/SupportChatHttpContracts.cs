namespace CareSitter.Modules.Support.Controllers.Contracts;

public sealed record ChatSendRequest(string Body);
public sealed record ChatReadRequest(long LastReadSequence);
public sealed record ChatVersionRequest(long ExpectedVersion);
public sealed record ChatTransferRequest(Guid TargetAdminId, bool Takeover,
    long ExpectedVersion, string Reason);
public sealed record ChatStatusRequest(string Status, long ExpectedVersion, string Reason);
