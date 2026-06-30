namespace CareSitter.SharedKernel.Domain;

/// <summary>
/// Goc cho moi entity dinh danh bang uuid.
/// </summary>
public abstract class Entity
{
    protected Entity(Guid id) => Id = id;
    protected Entity() { }

    public Guid Id { get; protected set; }

    public DateTimeOffset CreatedAt { get; protected set; }
    public DateTimeOffset UpdatedAt { get; protected set; }
}
