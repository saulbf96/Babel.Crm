using Microsoft.EntityFrameworkCore;

namespace Babel.Crm.Infrastructure.Persistencia;

/// <summary>
/// Contexto de EF Core sobre la base de BABEL. La base existente se respeta tal cual
/// (sin migraciones que la modifiquen) porque convive con los aplicativos de escritorio.
/// Las entidades se agregan conforme se documente el esquema de cada módulo.
/// </summary>
public sealed class BabelDbContext(DbContextOptions<BabelDbContext> options) : DbContext(options)
{
    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        modelBuilder.ApplyConfigurationsFromAssembly(typeof(BabelDbContext).Assembly);
    }
}
