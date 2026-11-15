using CareSitter.SharedKernel.Results;

namespace CareSitter.Modules.Identity.Application;

public sealed record IdentityPage<T>(IReadOnlyList<T> Items, int Total, int Page, int PageSize);
