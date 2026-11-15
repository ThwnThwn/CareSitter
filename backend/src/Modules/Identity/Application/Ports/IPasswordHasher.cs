using CareSitter.Modules.Identity.Domain;
using CareSitter.SharedKernel.Results;

namespace CareSitter.Modules.Identity.Application;

public interface IPasswordHasher
{
    string Hash(string password);
    bool Verify(string password, string? passwordHash);
}
