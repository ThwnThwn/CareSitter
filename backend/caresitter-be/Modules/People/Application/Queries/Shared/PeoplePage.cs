using System.Text.Json;

namespace CareSitter.Modules.People.Application;

public sealed record PeoplePage<T>(IReadOnlyList<T> Items, int Total, int Page, int PageSize);
