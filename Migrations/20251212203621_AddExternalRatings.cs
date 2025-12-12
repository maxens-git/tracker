using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace TrackerApi.Migrations
{
    /// <inheritdoc />
    public partial class AddExternalRatings : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<double>(
                name: "ImdbRating",
                table: "Shows",
                type: "double",
                nullable: true);

            migrationBuilder.AddColumn<long>(
                name: "ImdbVotes",
                table: "Shows",
                type: "bigint",
                nullable: true);

            migrationBuilder.AddColumn<double>(
                name: "RottenTomatoesRating",
                table: "Shows",
                type: "double",
                nullable: true);

            migrationBuilder.AddColumn<double>(
                name: "ImdbRating",
                table: "Movies",
                type: "double",
                nullable: true);

            migrationBuilder.AddColumn<long>(
                name: "ImdbVotes",
                table: "Movies",
                type: "bigint",
                nullable: true);

            migrationBuilder.AddColumn<double>(
                name: "RottenTomatoesRating",
                table: "Movies",
                type: "double",
                nullable: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "ImdbRating",
                table: "Shows");

            migrationBuilder.DropColumn(
                name: "ImdbVotes",
                table: "Shows");

            migrationBuilder.DropColumn(
                name: "RottenTomatoesRating",
                table: "Shows");

            migrationBuilder.DropColumn(
                name: "ImdbRating",
                table: "Movies");

            migrationBuilder.DropColumn(
                name: "ImdbVotes",
                table: "Movies");

            migrationBuilder.DropColumn(
                name: "RottenTomatoesRating",
                table: "Movies");
        }
    }
}
