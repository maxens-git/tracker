using System;
using Microsoft.EntityFrameworkCore.Metadata;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace TrackerApi.Migrations
{
    /// <inheritdoc />
    public partial class AddWatchHistory : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<int>(
                name: "WatchCount",
                table: "UserMedia",
                type: "int",
                nullable: false,
                defaultValue: 0);

            migrationBuilder.AddColumn<int>(
                name: "WatchCount",
                table: "UserEpisodes",
                type: "int",
                nullable: false,
                defaultValue: 0);

            migrationBuilder.CreateTable(
                name: "UserEpisodeWatchEvents",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("MySql:ValueGenerationStrategy", MySqlValueGenerationStrategy.IdentityColumn),
                    UserEpisodeId = table.Column<int>(type: "int", nullable: false),
                    WatchedAt = table.Column<DateTime>(type: "datetime(6)", nullable: false),
                    CreatedAt = table.Column<DateTime>(type: "datetime(6)", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_UserEpisodeWatchEvents", x => x.Id);
                    table.ForeignKey(
                        name: "FK_UserEpisodeWatchEvents_UserEpisodes_UserEpisodeId",
                        column: x => x.UserEpisodeId,
                        principalTable: "UserEpisodes",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                })
                .Annotation("MySql:CharSet", "utf8mb4");

            migrationBuilder.CreateTable(
                name: "UserMediaWatchEvents",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("MySql:ValueGenerationStrategy", MySqlValueGenerationStrategy.IdentityColumn),
                    UserMediaId = table.Column<int>(type: "int", nullable: false),
                    WatchedAt = table.Column<DateTime>(type: "datetime(6)", nullable: false),
                    CreatedAt = table.Column<DateTime>(type: "datetime(6)", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_UserMediaWatchEvents", x => x.Id);
                    table.ForeignKey(
                        name: "FK_UserMediaWatchEvents_UserMedia_UserMediaId",
                        column: x => x.UserMediaId,
                        principalTable: "UserMedia",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                })
                .Annotation("MySql:CharSet", "utf8mb4");

            migrationBuilder.CreateIndex(
                name: "IX_UserEpisodeWatchEvents_UserEpisodeId",
                table: "UserEpisodeWatchEvents",
                column: "UserEpisodeId");

            migrationBuilder.CreateIndex(
                name: "IX_UserEpisodeWatchEvents_WatchedAt",
                table: "UserEpisodeWatchEvents",
                column: "WatchedAt");

            migrationBuilder.CreateIndex(
                name: "IX_UserMediaWatchEvents_UserMediaId",
                table: "UserMediaWatchEvents",
                column: "UserMediaId");

            migrationBuilder.CreateIndex(
                name: "IX_UserMediaWatchEvents_WatchedAt",
                table: "UserMediaWatchEvents",
                column: "WatchedAt");

            // Backfill : chaque média/épisode déjà marqué "vu" devient 1 visionnage daté à AddedAt.
            migrationBuilder.Sql(@"
                INSERT INTO UserMediaWatchEvents (UserMediaId, WatchedAt, CreatedAt)
                SELECT Id, AddedAt, UTC_TIMESTAMP() FROM UserMedia WHERE Seen = 1;

                UPDATE UserMedia SET WatchCount = 1 WHERE Seen = 1;

                INSERT INTO UserEpisodeWatchEvents (UserEpisodeId, WatchedAt, CreatedAt)
                SELECT Id, AddedAt, UTC_TIMESTAMP() FROM UserEpisodes WHERE Seen = 1;

                UPDATE UserEpisodes SET WatchCount = 1 WHERE Seen = 1;
            ");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "UserEpisodeWatchEvents");

            migrationBuilder.DropTable(
                name: "UserMediaWatchEvents");

            migrationBuilder.DropColumn(
                name: "WatchCount",
                table: "UserMedia");

            migrationBuilder.DropColumn(
                name: "WatchCount",
                table: "UserEpisodes");
        }
    }
}
