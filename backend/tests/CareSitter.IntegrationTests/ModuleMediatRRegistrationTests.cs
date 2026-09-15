using CareSitter.Modules.Catalog;
using CareSitter.Modules.Catalog.Application;
using CareSitter.Modules.Catalog.Application.Commands.CreateAddress;
using CareSitter.Modules.People;
using CareSitter.Modules.People.Application;
using CareSitter.Modules.People.Application.Commands.CreateFamilyContact;
using CareSitter.Modules.Support;
using CareSitter.Modules.Support.Application;
using CareSitter.Modules.Support.Application.Commands.CreateDispute;
using CareSitter.SharedKernel.Results;
using MediatR;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;

namespace CareSitter.IntegrationTests;

public sealed class ModuleMediatRRegistrationTests
{
    private static readonly IConfiguration Configuration = new ConfigurationBuilder()
        .AddInMemoryCollection(new Dictionary<string, string?>
        {
            ["ConnectionStrings:CareSitter"] =
                "Host=localhost;Database=caresitter;Username=test;Password=test"
        })
        .Build();

    [Fact]
    public void Catalog_registers_command_handlers()
    {
        var services = new ServiceCollection();
        new CatalogModule().RegisterServices(services, Configuration);

        Assert.Contains(services, descriptor => descriptor.ServiceType ==
            typeof(IRequestHandler<CreateAddressCommand, Result<AddressResponse>>));
    }

    [Fact]
    public void People_registers_command_handlers()
    {
        var services = new ServiceCollection();
        new PeopleModule().RegisterServices(services, Configuration);

        Assert.Contains(services, descriptor => descriptor.ServiceType ==
            typeof(IRequestHandler<CreateFamilyContactCommand, Result<FamilyContactResponse>>));
    }

    [Fact]
    public void Support_registers_command_handlers()
    {
        var services = new ServiceCollection();
        new SupportModule().RegisterServices(services, Configuration);

        Assert.Contains(services, descriptor => descriptor.ServiceType ==
            typeof(IRequestHandler<CreateDisputeCommand, Result<DisputeResponse>>));
    }
}
