using Microsoft.EntityFrameworkCore;
using Tracker.Models;

namespace Tracker.Data;

public class ApiDbContext : DbContext
{
    public ApiDbContext(DbContextOptions<ApiDbContext> options) : base(options)
    {
    }

    public DbSet<Movie> Movies { get; set; } = null!;
    public DbSet<Show> Shows { get; set; } = null!;
    public DbSet<Season> Seasons { get; set; } = null!;
    public DbSet<Episode> Episodes { get; set; } = null!;
    public DbSet<MediaList> MediaLists { get; set; } = null!;

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        base.OnModelCreating(modelBuilder);

        modelBuilder.Entity<Movie>()
            .HasIndex(m => m.TmdbId)
            .IsUnique();

        modelBuilder.Entity<Show>()
            .HasIndex(s => s.TmdbId)
            .IsUnique();
            
        modelBuilder.Entity<Show>()
            .HasMany(s => s.Seasons)
            .WithOne(season => season.Show)
            .HasForeignKey(season => season.ShowId)
            .OnDelete(DeleteBehavior.Cascade);

        modelBuilder.Entity<Season>()
            .HasMany(s => s.Episodes)
            .WithOne(episode => episode.Season)
            .HasForeignKey(episode => episode.SeasonId)
            .OnDelete(DeleteBehavior.Cascade);

        modelBuilder.Entity<MediaList>()
            .HasMany(ml => ml.Movies)
            .WithMany();

        modelBuilder.Entity<MediaList>()
            .HasMany(ml => ml.Shows)
            .WithMany();

        modelBuilder.Entity<MediaList>()
            .HasIndex(ml => ml.Name)
            .IsUnique();
    }
}