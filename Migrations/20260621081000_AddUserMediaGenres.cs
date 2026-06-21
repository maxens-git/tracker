using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Migrations;
using Tracker.Data;

#nullable disable

namespace TrackerApi.Migrations
{
    [DbContext(typeof(ApiDbContext))]
    [Migration("20260621081000_AddUserMediaGenres")]
    public partial class AddUserMediaGenres : Migration
    {
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<string>(
                name: "GenreNamesJson",
                table: "UserMedia",
                type: "longtext",
                nullable: true)
                .Annotation("MySql:CharSet", "utf8mb4");
        }

        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "GenreNamesJson",
                table: "UserMedia");
        }
    }
}
