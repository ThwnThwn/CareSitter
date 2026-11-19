using CareSitter.SharedKernel.Modules;
using CareSitter.SharedKernel.Results;
using MediatR;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Storage;
using Microsoft.Extensions.DependencyInjection;

namespace CareSitter.Infrastructure.Persistence;

// Only explicitly registered workflows share a connection. Each module still owns its writes.
public sealed class AtomicModuleWriteBehavior<TCommand, TValue>(IServiceProvider services)
    : IPipelineBehavior<TCommand, Result<TValue>> where TCommand : notnull, IAtomicModuleCommand
{
    public async Task<Result<TValue>> Handle(TCommand request, RequestHandlerDelegate<Result<TValue>> next,
        CancellationToken ct)
    {
        var contexts = services.GetKeyedServices<ModuleDbContext>(request.TransactionGroup).ToArray();
        var owner = contexts.First();
        await using var transaction = await owner.Database.BeginTransactionAsync(ct);
        var joined = new List<(ModuleDbContext Context, string ConnectionString)>();
        var committed = false;
        try
        {
            foreach (var context in contexts.Skip(1))
            {
                var database = context.Database;
                joined.Add((context, database.GetConnectionString()!));
                database.SetDbConnection(owner.Database.GetDbConnection());
                await database.UseTransactionAsync(transaction.GetDbTransaction(), ct);
            }

            // Serialize conflicting decisions before reading their state, including retries.
            await owner.Database.ExecuteSqlInterpolatedAsync(
                $"SELECT pg_advisory_xact_lock(hashtextextended({request.LockKey}, 0))", ct);
            var result = await next();
            if (result.IsSuccess)
            {
                await transaction.CommitAsync(ct);
                committed = true;
            }
            return result;
        }
        finally
        {
            foreach (var (context, connectionString) in joined)
            {
                await context.Database.UseTransactionAsync(null, CancellationToken.None);
                context.Database.SetDbConnection(null);
                context.Database.SetConnectionString(connectionString);
            }
            if (!committed)
                foreach (var context in contexts) context.ChangeTracker.Clear();
        }
    }
}
