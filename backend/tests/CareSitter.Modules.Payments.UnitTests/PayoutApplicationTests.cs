using CareSitter.Contracts.Services;
using CareSitter.Modules.Payments.Application.Payouts;
using CareSitter.Modules.Payments.Application.Payouts.CreatePayout;
using CareSitter.Modules.Payments.Application.Payouts.ListPendingPayouts;
using CareSitter.Modules.Payments.Controllers;
using CareSitter.Modules.Payments.Domain;
using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Payments.UnitTests;

public sealed class PayoutApplicationTests
{
    [Fact]
    public void PayoutController_DependsOnlyOnMediator()
    {
        var constructor = Assert.Single(typeof(PayoutsController).GetConstructors());
        var parameter = Assert.Single(constructor.GetParameters());

        Assert.Equal(typeof(IMediator), parameter.ParameterType);
    }

    [Fact]
    public async Task CreateValidator_UsesHeaderFallbackAndRejectsWhitespaceAccount()
    {
        var validator = new CreatePayoutCommandValidator();
        var valid = new CreatePayoutCommand(
            100_000, "VCB", "NGUYEN VAN A", "0123456789", null, " header-key ");
        var invalid = valid with { AccountNumber = "   " };

        Assert.Equal("header-key", valid.ResolveIdempotencyKey());
        Assert.True((await validator.ValidateAsync(valid)).IsValid);
        var invalidResult = await validator.ValidateAsync(invalid);
        Assert.Contains(invalidResult.Errors,
            x => x.ErrorCode == "payout.account_number");
    }

    [Theory]
    [InlineData("PENDING", true)]
    [InlineData("all", true)]
    [InlineData("UNKNOWN", false)]
    public async Task PendingQueryValidator_RestrictsStatusFilter(
        string status,
        bool expectedValid)
    {
        var validator = new ListPendingPayoutsQueryValidator();
        var result = await validator.ValidateAsync(
            new ListPendingPayoutsQuery(status, 1, 20));

        Assert.Equal(expectedValid, result.IsValid);
    }

    [Fact]
    public async Task ValidationBehavior_ReturnsResultWithoutCallingHandler()
    {
        var validator = new CreatePayoutCommandValidator();
        var behavior = new PayoutValidationBehavior<
            CreatePayoutCommand,
            CreatePayoutResult>([validator]);
        var handlerCalled = false;
        var invalid = new CreatePayoutCommand(
            1, "VCB", "NGUYEN VAN A", "0123456789", "key", null);

        var result = await behavior.Handle(
            invalid,
            () =>
            {
                handlerCalled = true;
                return Task.FromResult<Result<CreatePayoutResult>>(
                    new CreatePayoutResult(null!, Created: true));
            },
            CancellationToken.None);

        Assert.False(result.IsSuccess);
        Assert.Equal("payout.amount", result.Error.Code);
        Assert.False(handlerCalled);
    }

    [Fact]
    public void Mapper_MasksCaregiverViewAndRevealsAdminView()
    {
        var payout = PayoutRequest.Create(
            Guid.NewGuid(),
            Guid.NewGuid(),
            "key",
            100_000,
            "VCB",
            "NGUYEN VAN A",
            "encrypted:0123456789").Value;
        var mapper = new PayoutMapper(new EncryptionStub());

        var masked = mapper.ToResponse(payout);
        var revealed = mapper.ToResponse(payout, revealAccountNumber: true);

        Assert.Equal("••••••6789", masked.AccountNumber);
        Assert.Equal("0123456789", revealed.AccountNumber);
    }

    private sealed class EncryptionStub : IEncryptionService
    {
        public string Encrypt(string plaintext) => $"encrypted:{plaintext}";
        public string Decrypt(string ciphertext) =>
            ciphertext.Replace("encrypted:", string.Empty);
        public string Hmac(string value) => value;
    }
}
