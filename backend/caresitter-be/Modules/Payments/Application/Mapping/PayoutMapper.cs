using System.Security.Cryptography;
using CareSitter.Contracts.Services;
using CareSitter.Modules.Payments.Domain;

namespace CareSitter.Modules.Payments.Application.Payouts;

internal sealed class PayoutMapper(IEncryptionService encryption)
{
    public PayoutResponse ToResponse(
        PayoutRequest payout,
        bool revealAccountNumber = false)
    {
        var accountNumber = ReadAccountNumber(payout.AccountNumberEncrypted);
        return new PayoutResponse(
            payout.Id,
            payout.CaregiverId,
            payout.WalletAccountId,
            payout.Amount,
            payout.BankName,
            payout.AccountHolderName,
            payout.Status,
            revealAccountNumber ? accountNumber : MaskAccountNumber(accountNumber),
            payout.RequestedAt,
            payout.ReviewedAt,
            payout.RejectReason);
    }

    private string ReadAccountNumber(string storedValue)
    {
        try
        {
            return encryption.Decrypt(storedValue);
        }
        catch (FormatException)
        {
            return storedValue;
        }
        catch (CryptographicException)
        {
            return storedValue;
        }
    }

    private static string MaskAccountNumber(string value) => value.Length <= 4
        ? value
        : new string('•', value.Length - 4) + value[^4..];
}
