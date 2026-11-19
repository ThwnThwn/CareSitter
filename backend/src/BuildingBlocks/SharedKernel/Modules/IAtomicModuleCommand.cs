namespace CareSitter.SharedKernel.Modules;

public interface IAtomicModuleCommand
{
    string TransactionGroup { get; }
    string LockKey { get; }
}
