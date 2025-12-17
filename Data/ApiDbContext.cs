using Microsoft.EntityFrameworkCore;
using Tracker.Models;
using Tracker.Models.Auth;

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
    public DbSet<MediaListMovie> MediaListMovies { get; set; } = null!;
    public DbSet<MediaListShow> MediaListShows { get; set; } = null!;
    public DbSet<RefreshToken> RefreshTokens { get; set; } = null!;

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
            .WithMany(m => m.MediaLists)
            .UsingEntity<MediaListMovie>(
                j => j.HasOne(x => x.Movie).WithMany(m => m.MediaListMovies).HasForeignKey(x => x.MovieId),
                j => j.HasOne(x => x.MediaList).WithMany(ml => ml.MediaListMovies).HasForeignKey(x => x.MediaListId))
            .Property(x => x.AddedAt)
            .HasColumnType("datetime(6)")
            .HasDefaultValueSql("CURRENT_TIMESTAMP(6)");

        modelBuilder.Entity<MediaList>()
            .HasMany(ml => ml.Shows)
            .WithMany(s => s.MediaLists)
            .UsingEntity<MediaListShow>(
                j => j.HasOne(x => x.Show).WithMany(s => s.MediaListShows).HasForeignKey(x => x.ShowId),
                j => j.HasOne(x => x.MediaList).WithMany(ml => ml.MediaListShows).HasForeignKey(x => x.MediaListId))
            .Property(x => x.AddedAt)
            .HasColumnType("datetime(6)")
            .HasDefaultValueSql("CURRENT_TIMESTAMP(6)");

        modelBuilder.Entity<MediaListMovie>()
            .HasKey(x => new { x.MediaListId, x.MovieId });

        modelBuilder.Entity<MediaListShow>()
            .HasKey(x => new { x.MediaListId, x.ShowId });

        modelBuilder.Entity<MediaList>()
            .HasIndex(ml => ml.Name)
            .IsUnique();

        modelBuilder.Entity<RefreshToken>()
            .HasIndex(rt => rt.Token)
            .IsUnique();

        modelBuilder.Entity<RefreshToken>()
            .HasIndex(rt => rt.Username);
    }
}