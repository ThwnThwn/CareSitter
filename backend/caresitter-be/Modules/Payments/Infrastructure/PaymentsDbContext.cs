using CareSitter.Infrastructure.Persistence;
using CareSitter.Infrastructure.Security;
using Microsoft.EntityFrameworkCore;

namespace CareSitter.Modules.Payments.Infrastructure;

/// <summary>DbContext module Payments — schema "payments" (wallet, payment_intents, ledger, payout).</summary>
public sealed class PaymentsDbContext : ModuleDbContext
{
    public const string SchemaName = "payments";

    public PaymentsDbContext(DbContextOptions<PaymentsDbContext> options, ICurrentUser? currentUser = null)
        : base(options, currentUser) { }

    protected override string Schema => SchemaName;
}
