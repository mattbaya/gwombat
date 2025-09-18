# CLAUDE.md – Project Notes and AI Pairing Context

## Overview (September 2025)
GWOMBAT (Google Workspace Optimization, Management, Backups And Taskrunner) is a Bash/SQlite operations platform for Google Workspace administrators. The codebase is dominated by the primary script `gwombat.sh` (~24k lines) plus 70+ utilities in `shared-utilities/`. A new SQLite-driven hierarchical menu system is under development, but many menu entries still point back to top-level screens or placeholder functions. The working portions of the tool (user lifecycle automation, CSV exports, shared drive basics) reside in the same script and can be invoked directly.

## Architecture Highlights
- **Main application**: `gwombat.sh` orchestrates configuration loading, GAM integration, logging, and hundreds of operational routines (user management, drive tooling, reporting)
- **Dynamic menu subsystem**: `shared-utilities/hierarchical_menu_system.sh` and `shared-utilities/enhanced_hierarchical_menu.sh` render menus from `shared-config/menu.db` (`menu_items_v2` table). `USE_HIERARCHICAL_MENUS` toggles the new renderer.
- **Database layer**: SQLite databases in `shared-config/` (shared menu data) and `local-config/gwombat.db` (instance-specific state). Helper wrappers live in `shared-utilities/database_functions.sh`.
- **Automation utilities**: setup wizard, export functions, drive management scripts, compliance bridges, and numerous targeted test harnesses are under `shared-utilities/`.

## Implementation Status
| Area | Status | Notes |
| --- | --- | --- |
| User & Group Management | ⚠️ Partial | Operational routines exist (password resets, bulk OU moves, suspended workflow stages), but menu entries like `individual_user_management_menu` and `bulk_user_operations_menu` now loop back to the root menu. Functions must be called manually until rewired. |
| File & Drive Operations | ⚠️ Partial | Core actions (list/create shared drives, manage members, run diagnostics) work; advanced analytics, permission cleanup, and backup operations remain “Coming Soon”. `backup_operations_menu` currently redirects to `system_administration`. |
| Analysis & Discovery | 🚧 Stubbed | `account_analysis` submenu is empty in `menu_items_v2`, and related functions print placeholder text. Documentation claiming comprehensive analytics is outdated. |
| Account List Management | ⚠️ Partial | CSV/database helpers exist, but top-level menu functions were rewritten to `render_menu "account_list_management"`, so interactive access is broken. |
| Dashboard & Statistics | ⚠️ Partial | Some reporting functions still operate, yet multiple menu options (e.g. login activity summaries) are stubs. |
| Reports & Monitoring | ⚠️ Partial | Similar to dashboard: structural menus exist, many actions are placeholders. |
| System Administration | 🚧 Stubbed | `system_maintenance_menu` and `system_backup_menu` only echo “Coming Soon”. |
| SCuBA Compliance | ⚠️ Partial | Compliance scripts exist, but the menu dispatchers need verification. |
| CSV Export System | ✅ Working | `shared-utilities/export_functions.sh` backs user/shared drive exports, account list exports, and metadata annotations. |
| Setup Wizard | ✅ Working | Handles `.env` generation, GAM/gyb/rclone config, directory scaffolding, and logging. |

## Known Issues & Gaps
- **Menu rewiring required** – Many `*_menu()` functions now call `render_menu "<root>"`, preventing access to the detailed routines defined later in the file.
- **Legacy loader** – `shared-utilities/menu_data_loader.sh` still targets the flat `menu_items` schema; running it will wipe `menu_items_v2` data. Create a new loader or guard the old one.
- **Placeholder functions** – `login_activity_summary`, `drive_usage_statistics`, `backup_operations_function_dispatcher`, and dozens of analytics/backup helpers only log forthcoming features. Keep them out of live menus until implemented.
- **Testing gaps** – Automated scripts (`test_hierarchical_menu.sh`, `test_menu_rendering.sh`) validate structure only; they do not cover workflows such as suspending a user, exporting data, or manipulating shared drives.
- **Documentation drift** – Prior README/docs promised fully operational hierarchical menus and advanced analytics. Adjust messaging to prevent operational surprises.

## Recommended Next Steps
1. **Repair menu routing** – For each `*_menu()` function that currently calls `render_menu`, point it to the correct submenu in `menu_items_v2` or reinstate the legacy interactive loop until the submenu exists. Examples: `individual_user_management_menu`, `account_search_diagnostics_menu`, `bulk_user_operations_menu`.
2. **Migrate data loader** – Update `menu_data_loader.sh` (or create `menu_data_loader_v2.sh`) to populate `menu_items_v2`, including parent-child relationships and keywords, so future deployments can rebuild the menu safely.
3. **Audit live menu items** – Remove or hide entries whose implementations echo “Coming Soon”, or back-fill the functionality before exposing them.
4. **Strengthen tests** – Add smoke tests that source `gwombat.sh`, call representative operations (`rescan_all_accounts`, `bulk_ou_moves_from_csv`, shared drive creation), and assert non-zero exit codes. Pair with linting and shellcheck where possible.
5. **Documentation updates** – Keep README, `docs/HIERARCHICAL_MENU_SYSTEM.md`, and deployment guides aligned with the real behaviour. Flag partial features clearly.

## Menu & Database Notes
- Active menu data lives in `shared-config/menu.db` → `menu_items_v2`, `menu_shortcuts`, `menu_config`.
- The recursive view `v_menu_hierarchy` powers breadcrumbs and search; ensure new inserts include `sort_order`, `item_type`, and `keywords`.
- Previous tables (`menu_sections`, `menu_items`, `menu_hierarchy`) still exist for legacy compatibility. Avoid mixing schemas.
- When editing the database manually, temporarily `chmod 644 shared-config/menu.db`, then restore to `444` (the menu scripts expect read-only permissions during runtime).

## Naming & Command Conventions
- Always refer to the project as **GWOMBAT** (Google Workspace Optimization, Management, Backups And Taskrunner). Avoid legacy names like “gamladmin”.
- GAM7 syntax is mandatory. Examples:
  ```bash
  gam create user <email> firstname "First" lastname "Last" password "TempPass" changepassword false
  gam create admin <email> _SEED_ADMIN_ROLE customer
  gam print shareddrives  # not teamdrives
  ```
- Keep `.env` variables in `local-config/.env`; the template `.env-template` documents expected keys (`DOMAIN`, `ADMIN_USER`, `GAM_PATH`, etc.).

## Dependencies & Tooling
- GAMADV-XTD3 (or latest GAM) for Google Workspace operations
- sqlite3 for database access
- Optional: Python 3.12+ for compliance dashboards (`python-modules/`), GYB for Gmail backups, rclone/restic for storage workflows
- Shell targets: currently tested on macOS (Bash 3.2) and Linux distributions

## Testing Reminders
- Syntax: `bash -n gwombat.sh` and `bash -n shared-utilities/*.sh`
- Structural menu tests: `./test_hierarchical_menu.sh`, `./test_menu_rendering.sh`
- Manual QA: launch `./gwombat.sh`, exercise domain sync, user suspension/restoration, CSV exports, shared drive member management. Confirm GAM output is displayed and logged (`local-config/logs/`).

## Memories
- 9 sounds good
