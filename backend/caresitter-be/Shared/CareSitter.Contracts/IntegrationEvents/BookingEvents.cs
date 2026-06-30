namespace CareSitter.Contracts.IntegrationEvents;

/// <summary>Booking thanh toan thanh cong -> Payments khoa escrow. (Payments -> Booking)</summary>
public sealed record PaymentSucceeded(Guid BookingId, Guid PaymentIntentId, long Amount) : IntegrationEvent;

/// <summary>Ca hoan tat -> Payments tinh phi + ghi nhan thu nhap CSV (pending 48h). (Booking -> Payments)</summary>
public sealed record BookingCompleted(Guid BookingId, Guid CaregiverId, long EscrowAmount) : IntegrationEvent;

/// <summary>SOS trong ca -> Support tao ticket CRITICAL. (Booking -> Support)</summary>
public sealed record SosRaised(Guid BookingId, Guid? RaisedByUserId) : IntegrationEvent;

/// <summary>Phan quyet tranh chap -> Payments ghi REFUND/PENALTY. (Support -> Payments)</summary>
public sealed record DisputeResolved(Guid BookingId, Guid DisputeId, string Decision,
    long RefundAmount, long CaregiverPenaltyAmount) : IntegrationEvent;

/// <summary>KYC duyet -> Identity/Notifications cho phep nhan ca + thong bao. (People -> *)</summary>
public sealed record KycApproved(Guid CaregiverId, Guid UserId) : IntegrationEvent;
