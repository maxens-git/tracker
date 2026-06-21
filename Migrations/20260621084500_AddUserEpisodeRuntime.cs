using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Migrations;
using Tracker.Data;

#nullable disable

namespace TrackerApi.Migrations
{
    [DbContext(typeof(ApiDbContext))]
    [Migration("20260621084500_AddUserEpisodeRuntime")]
    public partial class AddUserEpisodeRuntime : Migration
    {
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<int>(
                name: "Runtime",
                table: "UserEpisodes",
                type: "int",
                nullable: true);
        }

        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "Runtime",
                table: "UserEpisodes");
        }
    }
}
