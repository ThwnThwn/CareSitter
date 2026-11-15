namespace CareSitter.Contracts.IntegrationEvents;

/// <summary>Payments da khoa escrow thanh cong; Booking xac nhan lich theo eventual consistency.</summary>
public sealed record PaymentSucceeded(Guid BookingId, Guid PaymentIntentId, long Amount) : IntegrationEvent;

/// <summary>Payments da dong mot lan thanh toan that bai; Booking giai phong slot hold neu co.</summary>
public sealed record PaymentFailed(Guid BookingId, Guid PaymentIntentId, string Source) : IntegrationEvent;

/// <summary>Admin tu choi payment can doi soat; Booking huy lich va giai phong slot hold.</summary>
public sealed record PaymentReviewRejected(
    Guid BookingId, Guid PaymentIntentId, string Reason) : IntegrationEvent;

public sealed record PaymentReconciliationStarted(
    Guid BookingId, Guid PaymentIntentId) : IntegrationEvent;

public sealed record PaymentExpired(
    Guid BookingId, Guid? PaymentIntentId, string Reason) : IntegrationEvent;

public sealed record PaymentNeedsManualReview(
    Guid BookingId, Guid PaymentIntentId, string Reason) : IntegrationEvent;

/// <summary>Ca hoan tat -> Payments tinh phi + ghi nhan thu nhap CSV (pending 48h). (Booking -> Payments)</summary>
public sealed record BookingCompleted(Guid BookingId, Guid CaregiverId, long EscrowAmount) : IntegrationEvent;

/// <summary>SOS trong ca -> Support tao ticket CRITICAL. (Booking -> Support)</summary>
public sealed record SosRaised(Guid BookingId, Guid? RaisedByUserId) : IntegrationEvent;

/// <summary>Phan quyet tranh chap -> Payments ghi REFUND/PENALTY. (Support -> Payments)</summary>
public sealed record DisputeResolved(Guid BookingId, Guid DisputeId, string Decision,
    long RefundAmount, long CaregiverPenaltyAmount) : IntegrationEvent;

/// <summary>KYC duyet -> Identity/Notifications cho phep nhan ca + thong bao. (People -> *)</summary>
public sealed record KycApproved(Guid CaregiverId, Guid UserId) : IntegrationEvent;
