using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace Tracker.Models;

[Table("Persons")]
public class Person : BaseEntity
{
    [Key]
    public int Id { get; set; }

    [Required]
    public int TmdbId { get; set; }

    [Required]
    [MaxLength(255)]
    public string Name { get; set; } = string.Empty;

    [MaxLength(255)]
    public string? ProfilePath { get; set; }

    [MaxLength(100)]
    public string? KnownForDepartment { get; set; }

    public int Gender { get; set; }

    public double Popularity { get; set; }

    public List<MovieCast> MovieCasts { get; set; } = new();
    public List<MovieCrew> MovieCrews { get; set; } = new();
    public List<ShowCast> ShowCasts { get; set; } = new();
    public List<ShowCrew> ShowCrews { get; set; } = new();
}

[Table("MovieCasts")]
public class MovieCast
{
    public int MovieId { get; set; }
    public Movie Movie { get; set; } = null!;

    public int PersonId { get; set; }
    public Person Person { get; set; } = null!;

    [MaxLength(255)]
    public string? Character { get; set; }

    public int Order { get; set; }
}

[Table("MovieCrews")]
public class MovieCrew
{
    public int MovieId { get; set; }
    public Movie Movie { get; set; } = null!;

    public int PersonId { get; set; }
    public Person Person { get; set; } = null!;

    [MaxLength(100)]
    public string? Job { get; set; }

    [MaxLength(100)]
    public string? Department { get; set; }
}

[Table("ShowCasts")]
public class ShowCast
{
    public int ShowId { get; set; }
    public Show Show { get; set; } = null!;

    public int PersonId { get; set; }
    public Person Person { get; set; } = null!;

    [MaxLength(255)]
    public string? Character { get; set; }

    public int Order { get; set; }
}

[Table("ShowCrews")]
public class ShowCrew
{
    public int ShowId { get; set; }
    public Show Show { get; set; } = null!;

    public int PersonId { get; set; }
    public Person Person { get; set; } = null!;

    [MaxLength(100)]
    public string? Job { get; set; }

    [MaxLength(100)]
    public string? Department { get; set; }
}
