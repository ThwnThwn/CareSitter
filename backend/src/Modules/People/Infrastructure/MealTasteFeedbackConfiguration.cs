using CareSitter.Modules.People.Domain;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace CareSitter.Modules.People.Infrastructure;

internal sealed class MealTasteFeedbackConfiguration : IEntityTypeConfiguration<MealTasteFeedback>
{
    public void Configure(EntityTypeBuilder<MealTasteFeedback> b)
    {
        b.ToTable("meal_taste_feedback", "people");
        b.HasKey(x => x.Id);
        b.Property(x => x.Id).HasColumnName("id");
        b.Property(x => x.OwnerId).HasColumnName("owner_id");
        b.Property(x => x.BeneficiaryId).HasColumnName("beneficiary_id");
        b.Property(x => x.PlanId).HasColumnName("plan_id");
        b.Property(x => x.PlannedDate).HasColumnName("planned_date");
        b.Property(x => x.RecipeVersionId).HasColumnName("recipe_version_id");
        b.Property(x => x.MealType).HasColumnName("meal_type").HasMaxLength(20);
        b.Property(x => x.MealName).HasColumnName("meal_name").HasMaxLength(255);
        b.Property(x => x.Feedback).HasColumnName("feedback").HasMaxLength(20);
        b.Property(x => x.Status).HasColumnName("status").HasMaxLength(20);
        b.Property(x => x.SubmittedBy).HasColumnName("submitted_by");
        b.Property(x => x.SubmittedByRole).HasColumnName("submitted_by_role").HasMaxLength(20);
        b.Property(x => x.SubmittedAt).HasColumnName("submitted_at");
        b.Property(x => x.IdempotencyKey).HasColumnName("idempotency_key");
        b.Property(x => x.Fingerprint).HasColumnName("fingerprint").HasMaxLength(64);
        b.Property(x => x.ReviewedBy).HasColumnName("reviewed_by");
        b.Property(x => x.ReviewedAt).HasColumnName("reviewed_at");
        b.Property(x => x.AppliedHealthRevision).HasColumnName("applied_health_revision");
        b.HasIndex(x => new { x.OwnerId, x.BeneficiaryId, x.SubmittedBy, x.IdempotencyKey }).IsUnique();
    }
}
