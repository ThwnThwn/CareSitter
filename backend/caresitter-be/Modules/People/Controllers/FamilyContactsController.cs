using CareSitter.Infrastructure.Security;
using CareSitter.Modules.People.Application;
using CareSitter.Modules.People.Application.Commands.CreateFamilyContact;
using CareSitter.Modules.People.Application.Commands.DeleteFamilyContact;
using CareSitter.Modules.People.Application.Commands.UpdateFamilyContact;
using CareSitter.Modules.People.Domain;
using CareSitter.Modules.People.Infrastructure;
using MediatR;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Storage;

namespace CareSitter.Modules.People.Controllers;

[ApiController]
[Authorize]
[Route("api/v1/family-contacts")]
public sealed class FamilyContactsController(
    PeopleDbContext db, ICurrentUser currentUser, ISender sender) : ControllerBase
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
        var result = await sender.Send(new CreateFamilyContactCommand(
            request.FullName, request.PhoneNumber, request.Note), ct);
        return result.ToActionResult(this,
            contact => Created($"/api/v1/family-contacts/{contact.Id}", contact));
    }

    [HttpPut("{id:guid}")]
    public async Task<IActionResult> Update(Guid id, [FromBody] FamilyContactUpsertRequest request, CancellationToken ct)
    {
        var result = await sender.Send(new UpdateFamilyContactCommand(id,
            request.FullName, request.PhoneNumber, request.Note), ct);
        return result.ToActionResult(this);
    }

    [HttpDelete("{id:guid}")]
    public async Task<IActionResult> Delete(Guid id, CancellationToken ct)
    {
        var result = await sender.Send(new DeleteFamilyContactCommand(id), ct);
        return result.ToActionResult(this, _ => NoContent());
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

}

public sealed record FamilyContactUpsertRequest(string FullName, string PhoneNumber, string? Note);
