using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Migrations;
using Tracker.Data;

namespace TrackerApi.Migrations;

[DbContext(typeof(ApiDbContext))]
[Migration("20261114000000_AddIosNotificationPreference")]
public class AddIosNotificationPreference : Migration
{
    protected override void Up(MigrationBuilder migrationBuilder)
    {
        // MySQL peut valider le DDL avant qu'EF Core inscrive la migration dans son historique.
        // Au redémarrage, conserver une colonne déjà créée et la valeur qu'elle contient.
        migrationBuilder.Sql(
            """
            SET @tracker_ios_notification_ddl = IF(
                EXISTS (
                    SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
                    WHERE TABLE_SCHEMA = DATABASE()
                      AND TABLE_NAME = 'Settings'
                      AND COLUMN_NAME = 'IosLocalNotificationsEnabled'
                ),
                'SELECT 1',
                'ALTER TABLE `Settings` ADD `IosLocalNotificationsEnabled` tinyint(1) NULL'
            );
            PREPARE tracker_ios_notification_stmt FROM @tracker_ios_notification_ddl;
            EXECUTE tracker_ios_notification_stmt;
            DEALLOCATE PREPARE tracker_ios_notification_stmt;
            """,
            suppressTransaction: true);
    }

    protected override void Down(MigrationBuilder migrationBuilder)
    {
        migrationBuilder.DropColumn(name: "IosLocalNotificationsEnabled", table: "Settings");
    }
}
