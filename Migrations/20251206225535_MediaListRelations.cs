using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace TrackerApi.Migrations
{
    /// <inheritdoc />
    public partial class MediaListRelations : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "FK_MediaListMovie_Movies_MoviesId",
                table: "MediaListMovie");

            migrationBuilder.DropForeignKey(
                name: "FK_MediaListShow_Shows_ShowsId",
                table: "MediaListShow");

            migrationBuilder.RenameColumn(
                name: "ShowsId",
                table: "MediaListShow",
                newName: "ShowId");

            migrationBuilder.RenameIndex(
                name: "IX_MediaListShow_ShowsId",
                table: "MediaListShow",
                newName: "IX_MediaListShow_ShowId");

            migrationBuilder.RenameColumn(
                name: "MoviesId",
                table: "MediaListMovie",
                newName: "MovieId");

            migrationBuilder.RenameIndex(
                name: "IX_MediaListMovie_MoviesId",
                table: "MediaListMovie",
                newName: "IX_MediaListMovie_MovieId");

            migrationBuilder.AddForeignKey(
                name: "FK_MediaListMovie_Movies_MovieId",
                table: "MediaListMovie",
                column: "MovieId",
                principalTable: "Movies",
                principalColumn: "Id",
                onDelete: ReferentialAction.Cascade);

            migrationBuilder.AddForeignKey(
                name: "FK_MediaListShow_Shows_ShowId",
                table: "MediaListShow",
                column: "ShowId",
                principalTable: "Shows",
                principalColumn: "Id",
                onDelete: ReferentialAction.Cascade);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "FK_MediaListMovie_Movies_MovieId",
                table: "MediaListMovie");

            migrationBuilder.DropForeignKey(
                name: "FK_MediaListShow_Shows_ShowId",
                table: "MediaListShow");

            migrationBuilder.RenameColumn(
                name: "ShowId",
                table: "MediaListShow",
                newName: "ShowsId");

            migrationBuilder.RenameIndex(
                name: "IX_MediaListShow_ShowId",
                table: "MediaListShow",
                newName: "IX_MediaListShow_ShowsId");

            migrationBuilder.RenameColumn(
                name: "MovieId",
                table: "MediaListMovie",
                newName: "MoviesId");

            migrationBuilder.RenameIndex(
                name: "IX_MediaListMovie_MovieId",
                table: "MediaListMovie",
                newName: "IX_MediaListMovie_MoviesId");

            migrationBuilder.AddForeignKey(
                name: "FK_MediaListMovie_Movies_MoviesId",
                table: "MediaListMovie",
                column: "MoviesId",
                principalTable: "Movies",
                principalColumn: "Id",
                onDelete: ReferentialAction.Cascade);

            migrationBuilder.AddForeignKey(
                name: "FK_MediaListShow_Shows_ShowsId",
                table: "MediaListShow",
                column: "ShowsId",
                principalTable: "Shows",
                principalColumn: "Id",
                onDelete: ReferentialAction.Cascade);
        }
    }
}
