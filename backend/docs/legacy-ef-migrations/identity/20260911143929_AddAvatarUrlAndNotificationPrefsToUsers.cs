using System;
using Microsoft.EntityFrameworkCore.Migrations;

// Historical reference only: not compiled. Apply backend/init-db SQL instead.
#nullable disable

namespace CareSitter.Modules.Identity.Migrations
{
    /// <inheritdoc />
    public partial class AddAvatarUrlAndNotificationPrefsToUsers : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.EnsureSchema(
                name: "identity");

            migrationBuilder.AlterDatabase()
                .Annotation("Npgsql:PostgresExtension:postgis", ",,");

            migrationBuilder.CreateTable(
                name: "audit_logs",
                schema: "identity",
                columns: table => new
                {
                    id = table.Column<Guid>(type: "uuid", nullable: false),
                    actor_user_id = table.Column<Guid>(type: "uuid", nullable: true),
                    actor_role = table.Column<string>(type: "character varying(50)", maxLength: 50, nullable: true),
                    action = table.Column<string>(type: "character varying(150)", maxLength: 150, nullable: false),
                    entity_type = table.Column<string>(type: "character varying(100)", maxLength: 100, nullable: false),
                    entity_id = table.Column<Guid>(type: "uuid", nullable: true),
                    before_data = table.Column<string>(type: "jsonb", nullable: true),
                    after_data = table.Column<string>(type: "jsonb", nullable: true),
                    ip_address = table.Column<string>(type: "text", nullable: true),
                    user_agent = table.Column<string>(type: "text", nullable: true),
                    created_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_audit_logs", x => x.id);
                });

            migrationBuilder.CreateTable(
                name: "user_devices",
                schema: "identity",
                columns: table => new
                {
                    id = table.Column<Guid>(type: "uuid", nullable: false),
                    user_id = table.Column<Guid>(type: "uuid", nullable: false),
                    platform = table.Column<string>(type: "character varying(20)", maxLength: 20, nullable: false),
                    push_token = table.Column<string>(type: "text", nullable: true),
                    device_name = table.Column<string>(type: "character varying(255)", maxLength: 255, nullable: true),
                    biometric_enabled = table.Column<bool>(type: "boolean", nullable: false),
                    last_seen_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    created_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_user_devices", x => x.id);
                });

            migrationBuilder.CreateTable(
                name: "users",
                schema: "identity",
                columns: table => new
                {
                    id = table.Column<Guid>(type: "uuid", nullable: false),
                    phone = table.Column<string>(type: "character varying(20)", maxLength: 20, nullable: true),
                    email = table.Column<string>(type: "character varying(255)", maxLength: 255, nullable: false),
                    display_name = table.Column<string>(type: "character varying(255)", maxLength: 255, nullable: true),
                    avatar_media_id = table.Column<Guid>(type: "uuid", nullable: true),
                    avatar_url = table.Column<string>(type: "character varying(2048)", maxLength: 2048, nullable: true),
                    status = table.Column<string>(type: "character varying(50)", maxLength: 50, nullable: false),
                    roles = table.Column<string[]>(type: "varchar[]", nullable: false),
                    full_name = table.Column<string>(type: "character varying(255)", maxLength: 255, nullable: true),
                    date_of_birth = table.Column<DateOnly>(type: "date", nullable: true),
                    gender = table.Column<string>(type: "character varying(20)", maxLength: 20, nullable: true),
                    default_address_id = table.Column<Guid>(type: "uuid", nullable: true),
                    notification_prefs = table.Column<string>(type: "jsonb", nullable: true),
                    admin_department = table.Column<string>(type: "character varying(50)", maxLength: 50, nullable: true),
                    admin_role = table.Column<string>(type: "character varying(50)", maxLength: 50, nullable: true),
                    admin_permissions = table.Column<string>(type: "jsonb", nullable: true),
                    admin_is_active = table.Column<bool>(type: "boolean", nullable: true),
                    last_login_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    deleted_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    password_hash = table.Column<string>(type: "text", nullable: true),
                    google_id = table.Column<string>(type: "character varying(255)", maxLength: 255, nullable: true),
                    created_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    updated_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_users", x => x.id);
                });

            migrationBuilder.CreateIndex(
                name: "IX_users_google_id",
                schema: "identity",
                table: "users",
                column: "google_id",
                unique: true,
                filter: "google_id IS NOT NULL");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "audit_logs",
                schema: "identity");

            migrationBuilder.DropTable(
                name: "user_devices",
                schema: "identity");

            migrationBuilder.DropTable(
                name: "users",
                schema: "identity");
        }
    }
}
