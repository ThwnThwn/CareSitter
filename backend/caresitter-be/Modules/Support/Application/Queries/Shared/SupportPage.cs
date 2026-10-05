using CareSitter.SharedKernel.Results;

namespace CareSitter.Modules.Support.Application;

public sealed record SupportPage<T>(IReadOnlyList<T> Items, int Total, int Page, int PageSize);
