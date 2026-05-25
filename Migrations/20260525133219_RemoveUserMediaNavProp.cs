using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace TrackerApi.Migrations
{
    /// <inheritdoc />
    public partial class RemoveUserMediaNavProp : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "FK_MediaListItems_UserMedia_UserMediaId",
                table: "MediaListItems");

            migrationBuilder.DropIndex(
                name: "IX_MediaListItems_UserMediaId",
                table: "MediaListItems");

            migrationBuilder.DropColumn(
                name: "UserMediaId",
                table: "MediaListItems");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<int>(
                name: "UserMediaId",
                table: "MediaListItems",
                type: "int",
                nullable: true);

            migrationBuilder.CreateIndex(
                name: "IX_MediaListItems_UserMediaId",
                table: "MediaListItems",
                column: "UserMediaId");

            migrationBuilder.AddForeignKey(
                name: "FK_MediaListItems_UserMedia_UserMediaId",
                table: "MediaListItems",
                column: "UserMediaId",
                principalTable: "UserMedia",
                principalColumn: "Id");
        }
    }
}
