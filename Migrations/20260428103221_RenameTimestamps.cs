using System;
using Microsoft.EntityFrameworkCore.Metadata;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace TrackerApi.Migrations
{
    /// <inheritdoc />
    public partial class RenameTimestamps : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "RefreshTokens");

            migrationBuilder.RenameColumn(
                name: "LastUpdated",
                table: "Shows",
                newName: "UpdatedAt");

            migrationBuilder.RenameColumn(
                name: "LastUpdated",
                table: "Movies",
                newName: "UpdatedAt");

            migrationBuilder.RenameColumn(
                name: "CreatedAt",
                table: "MediaLists",
                newName: "AddedAt");

            migrationBuilder.AddColumn<DateTime>(
                name: "UpdatedAt",
                table: "Trailers",
                type: "datetime(6)",
                nullable: false,
                defaultValue: new DateTime(1, 1, 1, 0, 0, 0, 0, DateTimeKind.Unspecified));

            migrationBuilder.AddColumn<DateTime>(
                name: "UpdatedAt",
                table: "Persons",
                type: "datetime(6)",
                nullable: false,
                defaultValue: new DateTime(1, 1, 1, 0, 0, 0, 0, DateTimeKind.Unspecified));

            migrationBuilder.AddColumn<DateTime>(
                name: "UpdatedAt",
                table: "MediaListShow",
                type: "datetime(6)",
                nullable: false,
                defaultValue: new DateTime(1, 1, 1, 0, 0, 0, 0, DateTimeKind.Unspecified));

            migrationBuilder.AddColumn<DateTime>(
                name: "UpdatedAt",
                table: "MediaListMovie",
                type: "datetime(6)",
                nullable: false,
                defaultValue: new DateTime(1, 1, 1, 0, 0, 0, 0, DateTimeKind.Unspecified));
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "UpdatedAt",
                table: "Trailers");

            migrationBuilder.DropColumn(
                name: "UpdatedAt",
                table: "Persons");

            migrationBuilder.DropColumn(
                name: "UpdatedAt",
                table: "MediaListShow");

            migrationBuilder.DropColumn(
                name: "UpdatedAt",
                table: "MediaListMovie");

            migrationBuilder.RenameColumn(
                name: "UpdatedAt",
                table: "Shows",
                newName: "LastUpdated");

            migrationBuilder.RenameColumn(
                name: "UpdatedAt",
                table: "Movies",
                newName: "LastUpdated");

            migrationBuilder.RenameColumn(
                name: "AddedAt",
                table: "MediaLists",
                newName: "CreatedAt");

            migrationBuilder.CreateTable(
                name: "RefreshTokens",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("MySql:ValueGenerationStrategy", MySqlValueGenerationStrategy.IdentityColumn),
                    CreatedAt = table.Column<DateTime>(type: "datetime(6)", nullable: false),
                    ExpiresAt = table.Column<DateTime>(type: "datetime(6)", nullable: false),
                    ReplacedByToken = table.Column<string>(type: "longtext", nullable: true)
                        .Annotation("MySql:CharSet", "utf8mb4"),
                    RevokedAt = table.Column<DateTime>(type: "datetime(6)", nullable: true),
                    Token = table.Column<string>(type: "varchar(255)", nullable: false)
                        .Annotation("MySql:CharSet", "utf8mb4"),
                    Username = table.Column<string>(type: "varchar(255)", nullable: false)
                        .Annotation("MySql:CharSet", "utf8mb4")
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_RefreshTokens", x => x.Id);
                })
                .Annotation("MySql:CharSet", "utf8mb4");

            migrationBuilder.CreateIndex(
                name: "IX_RefreshTokens_Token",
                table: "RefreshTokens",
                column: "Token",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_RefreshTokens_Username",
                table: "RefreshTokens",
                column: "Username");
        }
    }
}
