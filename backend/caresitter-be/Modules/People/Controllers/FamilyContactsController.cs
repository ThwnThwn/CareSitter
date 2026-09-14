using CareSitter.Infrastructure.Security;
using CareSitter.Modules.People.Domain;
using CareSitter.Modules.People.Infrastructure;
using CareSitter.SharedKernel.Results;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Storage;

namespace CareSitter.Modules.People.Controllers;

[ApiController]
[Authorize]
[Route("api/v1/family-contacts")]
public sealed class FamilyContactsController(PeopleDbContext db, ICurrentUser currentUser) : ControllerBase
{
    [HttpGet]
    public async Task<IActionResult> List(CancellationToken ct)
    {
        if (currentUser.UserId is not { } userId) return Unauthorized();
        await using var tx = await BeginRls(userId, ct);
        var contacts = await db.FamilyContacts.AsNoTracking()
            .Where(x => x.CustomerId == userId && x.DeletedAt == null)
            .OrderBy(x => x.FullName)
            .ToListAsync(ct);
        return Ok(contacts.Select(ToResponse));
    }

    [HttpPost]
    public async Task<IActionResult> Create([FromBody] FamilyContactUpsertRequest request, CancellationToken ct)
    {
        if (currentUser.UserId is not { } userId) return Unauthorized();
        var contact = FamilyContact.Create(userId, request.FullName, request.PhoneNumber, request.Note);
        if (contact.IsFailure) return Failure(contact.Error);

        await using var tx = await BeginRls(userId, ct);
        var duplicate = await db.FamilyContacts.AnyAsync(x => x.CustomerId == userId &&
            x.PhoneNumber == contact.Value.PhoneNumber && x.DeletedAt == null, ct);
        if (duplicate)
            return Conflict(new ProblemDetails { Title = "family_contact.phone_exists", Detail = "So dien thoai nay da co trong danh ba gia dinh." });

        db.FamilyContacts.Add(contact.Value);
        await db.SaveChangesAsync(ct);
        await tx.CommitAsync(ct);
        return Created($"/api/v1/family-contacts/{contact.Value.Id}", ToResponse(contact.Value));
    }

    [HttpPut("{id:guid}")]
    public async Task<IActionResult> Update(Guid id, [FromBody] FamilyContactUpsertRequest request, CancellationToken ct)
    {
        if (currentUser.UserId is not { } userId) return Unauthorized();
        await using var tx = await BeginRls(userId, ct);
        var contact = await db.FamilyContacts.SingleOrDefaultAsync(x =>
            x.Id == id && x.CustomerId == userId && x.DeletedAt == null, ct);
        if (contact is null) return NotFound();
        var updated = contact.Update(request.FullName, request.PhoneNumber, request.Note);
        if (updated.IsFailure) return Failure(updated.Error);
        var duplicate = await db.FamilyContacts.AnyAsync(x => x.CustomerId == userId &&
            x.PhoneNumber == contact.PhoneNumber && x.Id != id && x.DeletedAt == null, ct);
        if (duplicate)
            return Conflict(new ProblemDetails { Title = "family_contact.phone_exists", Detail = "So dien thoai nay da co trong danh ba gia dinh." });
        await db.SaveChangesAsync(ct);
        await tx.CommitAsync(ct);
        return Ok(ToResponse(contact));
    }

    [HttpDelete("{id:guid}")]
    public async Task<IActionResult> Delete(Guid id, CancellationToken ct)
    {
        if (currentUser.UserId is not { } userId) return Unauthorized();
        await using var tx = await BeginRls(userId, ct);
        var contact = await db.FamilyContacts.SingleOrDefaultAsync(x =>
            x.Id == id && x.CustomerId == userId && x.DeletedAt == null, ct);
        if (contact is null) return NotFound();
        contact.Delete(DateTimeOffset.UtcNow);
        await db.SaveChangesAsync(ct);
        await tx.CommitAsync(ct);
        return NoContent();
    }

    private async Task<IDbContextTransaction> BeginRls(Guid userId, CancellationToken ct)
    {
        var tx = await db.Database.BeginTransactionAsync(ct);
        await db.Database.ExecuteSqlInterpolatedAsync(
            $"SELECT set_config('app.current_user_id', {userId.ToString()}, true)", ct);
        return tx;
    }

    private static FamilyContactResponse ToResponse(FamilyContact x) =>
        new(x.Id, x.FullName, x.PhoneNumber, x.Note);

    private IActionResult Failure(Error error) => BadRequest(
        new ProblemDetails { Title = error.Code, Detail = error.Message });
}

public sealed record FamilyContactUpsertRequest(string FullName, string PhoneNumber, string? Note);
public sealed record FamilyContactResponse(Guid Id, string FullName, string PhoneNumber, string? Note);
