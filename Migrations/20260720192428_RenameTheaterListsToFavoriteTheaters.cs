using System;
using Microsoft.EntityFrameworkCore.Metadata;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace TrackerApi.Migrations
{
    /// <inheritdoc />
    public partial class RenameTheaterListsToFavoriteTheaters : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            // Nouvelle table plate des cinémas favoris.
            migrationBuilder.CreateTable(
                name: "FavoriteTheaters",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("MySql:ValueGenerationStrategy", MySqlValueGenerationStrategy.IdentityColumn),
                    Code = table.Column<string>(type: "varchar(8)", maxLength: 8, nullable: false)
                        .Annotation("MySql:CharSet", "utf8mb4"),
                    IsActive = table.Column<bool>(type: "tinyint(1)", nullable: false),
                    Position = table.Column<int>(type: "int", nullable: false),
                    AddedAt = table.Column<DateTime>(type: "datetime(6)", nullable: false),
                    UpdatedAt = table.Column<DateTime>(type: "datetime(6)", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_FavoriteTheaters", x => x.Id);
                })
                .Annotation("MySql:CharSet", "utf8mb4");

            migrationBuilder.CreateIndex(
                name: "IX_FavoriteTheaters_Code",
                table: "FavoriteTheaters",
                column: "Code",
                unique: true);

            // Reprise des données : chaque code cinéma des anciennes listes devient un favori coché.
            // Codes dédupliqués, position par ordre alphabétique (déterministe, une seule requête).
            migrationBuilder.Sql(
                @"INSERT INTO FavoriteTheaters (Code, IsActive, Position, AddedAt)
                  SELECT d.Code, 1,
                         (SELECT COUNT(*) FROM (SELECT DISTINCT Code FROM TheaterListItems) d2 WHERE d2.Code < d.Code),
                         UTC_TIMESTAMP()
                  FROM (SELECT DISTINCT Code FROM TheaterListItems) d;");

            migrationBuilder.DropTable(
                name: "TheaterListItems");

            migrationBuilder.DropTable(
                name: "TheaterLists");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "FavoriteTheaters");

            migrationBuilder.CreateTable(
                name: "TheaterLists",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("MySql:ValueGenerationStrategy", MySqlValueGenerationStrategy.IdentityColumn),
                    AddedAt = table.Column<DateTime>(type: "datetime(6)", nullable: false),
                    IsDefault = table.Column<bool>(type: "tinyint(1)", nullable: false),
                    Name = table.Column<string>(type: "varchar(100)", maxLength: 100, nullable: false)
                        .Annotation("MySql:CharSet", "utf8mb4"),
                    UpdatedAt = table.Column<DateTime>(type: "datetime(6)", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_TheaterLists", x => x.Id);
                })
                .Annotation("MySql:CharSet", "utf8mb4");

            migrationBuilder.CreateTable(
                name: "TheaterListItems",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("MySql:ValueGenerationStrategy", MySqlValueGenerationStrategy.IdentityColumn),
                    TheaterListId = table.Column<int>(type: "int", nullable: false),
                    Code = table.Column<string>(type: "varchar(8)", maxLength: 8, nullable: false)
                        .Annotation("MySql:CharSet", "utf8mb4"),
                    Position = table.Column<int>(type: "int", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_TheaterListItems", x => x.Id);
                    table.ForeignKey(
                        name: "FK_TheaterListItems_TheaterLists_TheaterListId",
                        column: x => x.TheaterListId,
                        principalTable: "TheaterLists",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                })
                .Annotation("MySql:CharSet", "utf8mb4");

            migrationBuilder.CreateIndex(
                name: "IX_TheaterListItems_TheaterListId_Code",
                table: "TheaterListItems",
                columns: new[] { "TheaterListId", "Code" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_TheaterLists_Name",
                table: "TheaterLists",
                column: "Name",
                unique: true);
        }
    }
}
