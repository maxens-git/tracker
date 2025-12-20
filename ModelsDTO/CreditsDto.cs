namespace Tracker.ModelsDTO;

public class CastMemberDto
{
    public int Id { get; set; }
    public string Name { get; set; } = string.Empty;
    public string? Character { get; set; }
    public string? ProfilePath { get; set; }
    public int Order { get; set; }
    public string? KnownForDepartment { get; set; }
}

public class CrewMemberDto
{
    public int Id { get; set; }
    public string Name { get; set; } = string.Empty;
    public string? Job { get; set; }
    public string? Department { get; set; }
    public string? ProfilePath { get; set; }
}

public class CreditsResponseDto
{
    public int TmdbId { get; set; }
    public List<CastMemberDto> Cast { get; set; } = new();
    public List<CrewMemberDto> Crew { get; set; } = new();
}
