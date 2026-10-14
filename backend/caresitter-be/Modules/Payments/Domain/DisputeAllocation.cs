using CareSitter.SharedKernel.Results;

namespace CareSitter.Modules.Payments.Domain;

internal sealed record DisputeAllocation(string Decision, long Refund, long Fee, long Penalty, long CaregiverEarning)
{
    public static Result<DisputeAllocation> Create(long escrowAmount, long platformFeeAmount,
        string decision, long? refundAmount, long? caregiverPenaltyAmount)
    {
        if (escrowAmount <= 0 || platformFeeAmount < 0 || platformFeeAmount > escrowAmount)
            return Error.Validation("payments.dispute.amounts", "Số tiền escrow không hợp lệ.");

        var normalizedDecision = decision.Trim().ToUpperInvariant();
        long refund;
        switch (normalizedDecision)
        {
            case "CUSTOMER_WINS":
                refund = escrowAmount;
                break;
            case "CAREGIVER_WINS":
                refund = 0;
                break;
            case "PARTIAL_REFUND":
                if (refundAmount is null || refundAmount <= 0 || refundAmount >= escrowAmount)
                    return Error.Validation("payments.dispute.refund",
                        "Hoàn tiền một phần phải lớn hơn 0 và nhỏ hơn escrow.");
                refund = refundAmount.Value;
                break;
            default:
                return Error.Validation("payments.dispute.decision", "Phán quyết không hợp lệ.");
        }

        var requestedPenalty = caregiverPenaltyAmount ?? 0;
        if (requestedPenalty < 0)
            return Error.Validation("payments.dispute.penalty",
                "Mức phạt caregiver không được âm.");

        var remaining = escrowAmount - refund;
        var fee = Math.Min(platformFeeAmount, remaining);
        var maximumPenalty = Math.Max(0, remaining - fee);
        // Only a partial split can deduct a penalty from the caregiver's share.
        // For a full customer/caregiver win the value remains an administrative
        // dispute outcome; it must not create money outside the locked escrow.
        var penalty = normalizedDecision == "PARTIAL_REFUND" ? requestedPenalty : 0;
        if (penalty > maximumPenalty)
            return Error.Validation("payments.dispute.penalty",
                "Mức phạt caregiver vượt quá phần thu nhập còn lại.");
        var caregiverAmount = remaining - fee - penalty;


        return new DisputeAllocation(normalizedDecision, refund, fee, penalty, caregiverAmount);
    }
}
