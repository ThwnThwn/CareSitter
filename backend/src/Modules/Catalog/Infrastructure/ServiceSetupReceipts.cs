using CareSitter.Modules.Catalog.Application;
using Microsoft.EntityFrameworkCore;

namespace CareSitter.Modules.Catalog.Infrastructure;

internal sealed class ServiceSetupReceipts(CatalogDbContext db) : IServiceSetupReceipts
{
    public Task<ServiceSetupReceipt?> FindAsync(Guid admin, Guid requestId, CancellationToken ct) =>
        db.Database.SqlQuery<ServiceSetupReceipt>($"""
            SELECT service_id AS "ServiceId", payload_hash AS "PayloadHash" FROM catalog.service_setup_receipts
            WHERE admin_id = {admin} AND request_id = {requestId}
            """).SingleOrDefaultAsync(ct);
    public Task SaveAsync(Guid admin, Guid requestId, Guid serviceId, string hash, CancellationToken ct) =>
        db.Database.ExecuteSqlInterpolatedAsync($"""
            INSERT INTO catalog.service_setup_receipts (admin_id, request_id, service_id, payload_hash)
            VALUES ({admin}, {requestId}, {serviceId}, {hash})
            """, ct);
}
