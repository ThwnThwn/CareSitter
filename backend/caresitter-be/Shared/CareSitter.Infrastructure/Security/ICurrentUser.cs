namespace CareSitter.Infrastructure.Security;

/// <summary>
/// User cua request hien tai. Dung de set GUC `app.current_user_id` cho RLS tren beneficiaries.
/// </summary>
public interface ICurrentUser
{
    Guid? UserId { get; }
    IReadOnlyCollection<string> Roles { get; }
    bool IsInRole(string role);
}
