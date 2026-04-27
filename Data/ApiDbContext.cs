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
    public DbSet<MediaListMovie> MediaListMovies { get; set; } = null!;
    public DbSet<MediaListShow> MediaListShows { get; set; } = null!;
    public DbSet<Person> Persons { get; set; } = null!;
    public DbSet<MovieCast> MovieCasts { get; set; } = null!;
    public DbSet<MovieCrew> MovieCrews { get; set; } = null!;
    public DbSet<ShowCast> ShowCasts { get; set; } = null!;
    public DbSet<ShowCrew> ShowCrews { get; set; } = null!;
    public DbSet<Trailer> Trailers { get; set; } = null!;

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

        // Person
        modelBuilder.Entity<Person>()
            .HasIndex(p => p.TmdbId)
            .IsUnique();

        // MovieCast
        modelBuilder.Entity<MovieCast>()
            .HasKey(mc => new { mc.MovieId, mc.PersonId });

        modelBuilder.Entity<MovieCast>()
            .HasOne(mc => mc.Movie)
            .WithMany(m => m.MovieCasts)
            .HasForeignKey(mc => mc.MovieId)
            .OnDelete(DeleteBehavior.Cascade);

        modelBuilder.Entity<MovieCast>()
            .HasOne(mc => mc.Person)
            .WithMany(p => p.MovieCasts)
            .HasForeignKey(mc => mc.PersonId)
            .OnDelete(DeleteBehavior.Cascade);

        // MovieCrew
        modelBuilder.Entity<MovieCrew>()
            .HasKey(mc => new { mc.MovieId, mc.PersonId, mc.Job });

        modelBuilder.Entity<MovieCrew>()
            .HasOne(mc => mc.Movie)
            .WithMany(m => m.MovieCrews)
            .HasForeignKey(mc => mc.MovieId)
            .OnDelete(DeleteBehavior.Cascade);

        modelBuilder.Entity<MovieCrew>()
            .HasOne(mc => mc.Person)
            .WithMany(p => p.MovieCrews)
            .HasForeignKey(mc => mc.PersonId)
            .OnDelete(DeleteBehavior.Cascade);

        // ShowCast
        modelBuilder.Entity<ShowCast>()
            .HasKey(sc => new { sc.ShowId, sc.PersonId });

        modelBuilder.Entity<ShowCast>()
            .HasOne(sc => sc.Show)
            .WithMany(s => s.ShowCasts)
            .HasForeignKey(sc => sc.ShowId)
            .OnDelete(DeleteBehavior.Cascade);

        modelBuilder.Entity<ShowCast>()
            .HasOne(sc => sc.Person)
            .WithMany(p => p.ShowCasts)
            .HasForeignKey(sc => sc.PersonId)
            .OnDelete(DeleteBehavior.Cascade);

        // ShowCrew
        modelBuilder.Entity<ShowCrew>()
            .HasKey(sc => new { sc.ShowId, sc.PersonId, sc.Job });

        modelBuilder.Entity<ShowCrew>()
            .HasOne(sc => sc.Show)
            .WithMany(s => s.ShowCrews)
            .HasForeignKey(sc => sc.ShowId)
            .OnDelete(DeleteBehavior.Cascade);

        modelBuilder.Entity<ShowCrew>()
            .HasOne(sc => sc.Person)
            .WithMany(p => p.ShowCrews)
            .HasForeignKey(sc => sc.PersonId)
            .OnDelete(DeleteBehavior.Cascade);

        // Trailers
        modelBuilder.Entity<Trailer>()
            .HasIndex(t => t.TmdbKey)
            .IsUnique();

        modelBuilder.Entity<Trailer>()
            .HasOne(t => t.Movie)
            .WithMany(m => m.Trailers)
            .HasForeignKey(t => t.MovieId)
            .OnDelete(DeleteBehavior.Cascade);

        modelBuilder.Entity<Trailer>()
            .HasOne(t => t.Show)
            .WithMany(s => s.Trailers)
            .HasForeignKey(t => t.ShowId)
            .OnDelete(DeleteBehavior.Cascade);
    }
}