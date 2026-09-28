using CareSitter.Contracts.Services;
using CareSitter.Modules.Booking.Application;
using CareSitter.Modules.Booking.Domain;
using CareSitter.SharedKernel.Results;
using Microsoft.EntityFrameworkCore;

namespace CareSitter.Modules.Booking.Infrastructure;

internal sealed class ChecklistTemplateManager(
    BookingDbContext bookingDb,
    IServiceChecklistCatalog catalog,
    IAuditLogger auditLogger) : IChecklistTemplateManager
{
    public async Task<Result<ChecklistPolicyResponse>> SetPolicyAsync(
        Guid serviceTypeId, bool allowAdHocTasks, CancellationToken ct = default)
    {
        var change = await catalog.SetPolicyAsync(serviceTypeId, allowAdHocTasks, ct);
        if (change is null) return NotFound();
        await auditLogger.WriteAsync("ADMIN_CHECKLIST_POLICY_UPDATED", "ServiceType",
            change.ServiceTypeId,
            new { AllowAdHocTasks = change.PreviousAllowAdHocTasks },
            new { change.AllowAdHocTasks }, ct);
        return new ChecklistPolicyResponse(change.ServiceTypeId, change.AllowAdHocTasks);
    }

    public async Task<Result<IReadOnlyList<ChecklistTemplateResponse>>> ListAsync(
        Guid serviceTypeId, CancellationToken ct = default)
    {
        if (!await catalog.ExistsAsync(serviceTypeId, ct))
            return NotFound();
        var templates = await bookingDb.PackageTaskTemplates.AsNoTracking()
            .Where(x => x.ServiceTypeId == serviceTypeId)
            .OrderBy(x => x.SortOrder).ThenBy(x => x.Name).ToListAsync(ct);
        return Result.Success<IReadOnlyList<ChecklistTemplateResponse>>(
            templates.Select(ToResponse).ToArray());
    }

    public async Task<Result<ChecklistTemplateResponse>> CreateAsync(
        Guid serviceTypeId, ChecklistTemplateInput input, CancellationToken ct = default)
    {
        var validation = Validate(input);
        if (validation is not null) return validation;
        if (!await catalog.ExistsAsync(serviceTypeId, ct))
            return NotFound();
        if (await bookingDb.PackageTaskTemplates.AnyAsync(
                x => x.ServiceTypeId == serviceTypeId && x.Name == input.Name.Trim(), ct))
            return Duplicate();
        var template = PackageTaskTemplate.Create(serviceTypeId, input.Name, input.Description,
            input.IsRequired, input.RequiresPhoto, input.SortOrder);
        bookingDb.PackageTaskTemplates.Add(template);
        await bookingDb.SaveChangesAsync(ct);
        var response = ToResponse(template);
        await auditLogger.WriteAsync("ADMIN_CHECKLIST_TEMPLATE_CREATED",
            "PackageTaskTemplate", template.Id, null, response, ct);
        return response;
    }

    public async Task<Result<ChecklistTemplateResponse>> UpdateAsync(
        Guid serviceTypeId, Guid templateId, ChecklistTemplateInput input,
        CancellationToken ct = default)
    {
        var validation = Validate(input);
        if (validation is not null) return validation;
        var template = await bookingDb.PackageTaskTemplates.SingleOrDefaultAsync(
            x => x.Id == templateId && x.ServiceTypeId == serviceTypeId, ct);
        if (template is null) return NotFound();
        if (await bookingDb.PackageTaskTemplates.AnyAsync(x =>
                x.ServiceTypeId == serviceTypeId && x.Id != templateId &&
                x.Name == input.Name.Trim(), ct)) return Duplicate();
        var before = ToResponse(template);
        template.Update(input.Name, input.Description, input.IsRequired,
            input.RequiresPhoto, input.SortOrder);
        await bookingDb.SaveChangesAsync(ct);
        var response = ToResponse(template);
        await auditLogger.WriteAsync("ADMIN_CHECKLIST_TEMPLATE_UPDATED",
            "PackageTaskTemplate", template.Id, before, response, ct);
        return response;
    }

    public async Task<Result<ChecklistTemplateResponse>> SetActiveAsync(
        Guid serviceTypeId, Guid templateId, bool isActive, CancellationToken ct = default)
    {
        var template = await bookingDb.PackageTaskTemplates.SingleOrDefaultAsync(
            x => x.Id == templateId && x.ServiceTypeId == serviceTypeId, ct);
        if (template is null) return NotFound();
        var before = ToResponse(template);
        template.SetActive(isActive);
        await bookingDb.SaveChangesAsync(ct);
        var response = ToResponse(template);
        await auditLogger.WriteAsync("ADMIN_CHECKLIST_TEMPLATE_ACTIVE_UPDATED",
            "PackageTaskTemplate", template.Id, before, response, ct);
        return response;
    }

    public async Task<Result> DeleteAsync(
        Guid serviceTypeId, Guid templateId, CancellationToken ct = default)
    {
        var template = await bookingDb.PackageTaskTemplates.SingleOrDefaultAsync(
            x => x.Id == templateId && x.ServiceTypeId == serviceTypeId, ct);
        if (template is null) return NotFound();
        var before = ToResponse(template);
        bookingDb.PackageTaskTemplates.Remove(template);
        await bookingDb.SaveChangesAsync(ct);
        await auditLogger.WriteAsync("ADMIN_CHECKLIST_TEMPLATE_DELETED",
            "PackageTaskTemplate", template.Id, before, null, ct);
        return Result.Success();
    }

    private static Error? Validate(ChecklistTemplateInput input)
    {
        if (string.IsNullOrWhiteSpace(input.Name) || input.Name.Trim().Length is < 3 or > 255)
            return Error.Validation("checklist.name", "Tên công việc phải có từ 3 đến 255 ký tự.");
        if (input.Description?.Trim().Length > 1000)
            return Error.Validation("checklist.description", "Mô tả công việc tối đa 1000 ký tự.");
        if (input.SortOrder is < 0 or > 1000)
            return Error.Validation("checklist.sort_order", "Thứ tự phải nằm trong khoảng từ 0 đến 1000.");
        return null;
    }

    private static Error NotFound() => Error.NotFound("checklist.not_found", "Không tìm thấy dữ liệu.");
    private static Error Duplicate() => Error.Conflict(
        "checklist.duplicate", "Checklist của gói đã có công việc cùng tên.");
    private static ChecklistTemplateResponse ToResponse(PackageTaskTemplate template) => new(
        template.Id, template.ServiceTypeId, template.Name, template.Description,
        template.IsRequired, template.RequiresPhoto, template.SortOrder, template.IsActive);
}
