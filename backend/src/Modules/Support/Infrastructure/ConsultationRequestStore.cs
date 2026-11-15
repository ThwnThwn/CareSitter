using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using CareSitter.Modules.Support.Application;
using CareSitter.Modules.Support.Application.Consultations;
using CareSitter.Modules.Support.Domain;
using CareSitter.SharedKernel.Results;
using Microsoft.EntityFrameworkCore;

namespace CareSitter.Modules.Support.Infrastructure;

public sealed class ConsultationRequestStore(SupportDbContext db) : IConsultationRequestStore
{
    public async Task<Result<ConsultationReceipt>> SaveAsync(ConsultationRequest request,
        CancellationToken ct)
    {
        var hash = Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(
            JsonSerializer.Serialize(new { request.ContactName, request.Phone,
                request.ServiceCategory, request.PreferredDate, request.Hours,
                request.CaregiverPreference, request.Note }))));
        var existing = await db.Set<ConsultationRequest>().AsNoTracking()
            .SingleOrDefaultAsync(x => x.Id == request.Id, ct);
        if (existing is not null) return ReceiptFor(existing, hash);
        var validation = request.ValidateNewSubmission();
        if (validation.IsFailure) return validation.Error;
        // The unique ID is the durable idempotency key. ON CONFLICT waits for
        // a concurrent insert; the following read compares the committed payload.
        await db.Database.ExecuteSqlInterpolatedAsync($"""
            INSERT INTO support.consultation_requests
                (id, contact_name, phone, service_category, preferred_date, hours,
                 caregiver_preference, note, consent_at, created_at, payload_hash)
            VALUES ({request.Id}, {request.ContactName}, {request.Phone}, {request.ServiceCategory},
                {request.PreferredDate}, {request.Hours}, {request.CaregiverPreference}, {request.Note},
                {request.ConsentAt}, {request.CreatedAt}, {hash})
            ON CONFLICT (id) DO NOTHING
            """, ct);
        var saved = await db.Set<ConsultationRequest>().AsNoTracking()
            .SingleAsync(x => x.Id == request.Id, ct);
        return ReceiptFor(saved, hash);
    }

    private static Result<ConsultationReceipt> ReceiptFor(ConsultationRequest saved, string hash)
    {
        if (saved.PayloadHash != hash)
            return Error.Conflict("consultation.key_conflict",
                "Mã yêu cầu đã dùng cho nội dung khác. Vui lòng gửi yêu cầu mới.");
        return new ConsultationReceipt(saved.Id, saved.CreatedAt);
    }

    public async Task<SupportPage<ConsultationResponse>> ListAsync(int page, int pageSize,
        CancellationToken ct)
    {
        var query = db.Set<ConsultationRequest>().AsNoTracking();
        var count = await query.CountAsync(ct);
        var items = await query.OrderByDescending(x => x.CreatedAt).ThenBy(x => x.Id)
            .Skip((page - 1) * pageSize).Take(pageSize)
            .Select(x => new ConsultationResponse(x.Id, x.ContactName, x.Phone, x.ServiceCategory,
                x.PreferredDate, x.Hours, x.CaregiverPreference, x.Note, x.ConsentAt, x.CreatedAt))
            .ToListAsync(ct);
        return new SupportPage<ConsultationResponse>(items, count, page, pageSize);
    }
}
