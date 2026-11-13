using Microsoft.Data.Sqlite;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Diagnostics;
using Tracker.Data;

namespace Tracker.Tests;

internal sealed class TestDatabase : IAsyncDisposable
{
    private readonly SqliteConnection connection = new("Data Source=:memory:");

    public ApiDbContext Context { get; }

    public TestDatabase(params IInterceptor[] interceptors)
    {
        connection.Open();
        Context = new ApiDbContext(new DbContextOptionsBuilder<ApiDbContext>()
            .UseSqlite(connection)
            .AddInterceptors(interceptors)
            .Options);
        Context.Database.EnsureCreated();
    }

    public async ValueTask DisposeAsync()
    {
        await Context.DisposeAsync();
        await connection.DisposeAsync();
    }
}
