# GWOMBAT Menu Migration – Next Tasks

## High Priority
- Convert remaining File & Drive Operations submenu actions into `menu_items_v2` entries (shared drive tooling, cleanup utilities, permission management, backups) and point interactive flows to the new hierarchy.
- Build hierarchical entries for Account List Management (CSV import/export, automation, verification) with corresponding SQLite records and dispatcher wiring.
- Restructure Dashboard & Statistics, Reports & Monitoring, System Administration, SCuBA Compliance, and Configuration Management menus to eliminate `render_menu` placeholders.
- For each new submenu, audit the referenced functions (replace "Coming Soon" stubs or hide unfinished actions until implemented).

## Medium Priority
- Update automated tests to cover hierarchical traversal (e.g. smoke test each submenu, ensure `render_menu` resolves correctly).
- Add migration safeguards so legacy scripts (e.g. `menu_data_loader.sh`) no longer wipe `menu_items_v2` tables.
- Generate documentation snippets (README/docs) for remaining sections once their hierarchical menus are live.

## Low Priority / Nice to Have
- Implement placeholder analytics/AI functions that the new menu structure exposes (e.g. `ai_insights_menu`, `drive_quick_search`).
- Create scripted verification that ensures every `_menu()` function invoked by the database actually exists and is functional.
- Clean up legacy backup scripts and extra utilities once menu conversion is complete.
