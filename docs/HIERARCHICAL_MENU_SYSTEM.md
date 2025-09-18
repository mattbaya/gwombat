# GWOMBAT Hierarchical Menu System

## Current State
The hierarchical menu refactor replaces 50+ hardcoded menu blocks with a database-driven renderer (`shared-utilities/hierarchical_menu_system.sh` and `shared-utilities/enhanced_hierarchical_menu.sh`). Menu metadata now lives in `shared-config/menu.db` (`menu_items_v2`, `menu_shortcuts`, `menu_config`, and the `v_menu_hierarchy` view). The renderer supports breadcrumbs, keyboard shortcuts, and an optional arrow-key UI.

However, the migration is only partially complete:
- Many `*_menu()` functions inside `gwombat.sh` were auto-rewritten to `render_menu "<root>"`, so selecting those items simply reopens the top-level menu.
- Large feature families (analytics, system maintenance, backup operations) still print "Coming Soon" while their menu entries remain visible.
- The legacy loader (`shared-utilities/menu_data_loader.sh`) still repopulates the old `menu_sections` / `menu_items` schema. Running it will wipe the new hierarchical data.

## Menu Inventory (menu_items_v2)
| Root Menu | Notes |
| --- | --- |
| `user_group_management` | 20 action entries exist, but several (`individual_user_management_menu`, `bulk_user_operations_menu`, `group_operations_menu`) now loop back to the root menu instead of presenting their sub-options. Manual invocation of the underlying functions still works. |
| `file_drive_operations` | Core shared-drive routines execute successfully. Analytics and backup actions (`backup_operations_menu`, `drive_cleanup_menu`, `permission_management_menu`) redirect to other roots or display "Coming Soon" text. |
| `analysis_discovery` | Menu structure is present, yet the intended submenu `account_analysis` has no children in `menu_items_v2`. The referenced analytics functions are unfinished. |
| `account_list_management` | Contains entries for list management and CSV/database workflows, but each action currently calls `render_menu "account_list_management"`. |
| `dashboard_statistics` | The renderer shows `System Overview` and `Statistics & Metrics` submenus. Several actions underneath them are placeholders. |
| `reports_monitoring` | Similar to dashboard: high-level items exist, detailed implementations pending. |
| `system_administration` | Exposed items (`system_maintenance_menu`, `system_backup_menu`) output "Coming Soon". |
| `scuba_compliance` | Compliance routines exist but have not been revalidated in the new navigation. |
| `configuration_management` | Empty in `menu_items_v2`. Configuration flows still live in `shared-utilities/config_manager.sh` and are sourced directly when available. |

Use `sqlite3 shared-config/menu.db 'SELECT id,name,parent_id,item_type,function_name FROM menu_items_v2 ORDER BY parent_id,sort_order;'` to inspect the live hierarchy.

## Editing the Hierarchy
1. **Back up the database** before making changes: `cp shared-config/menu.db shared-config/menu_backup_$(date +%Y%m%d_%H%M%S).db`.
2. Temporarily enable write access: `chmod 644 shared-config/menu.db` (restore to `444` afterwards).
3. Insert/update rows in `menu_items_v2` with consistent `name`, `item_type`, `sort_order`, and `parent_id` values. Ensure action items reference real functions in `gwombat.sh` or supporting scripts.
4. Update `menu_shortcuts` if you add global navigation keys.
5. Regenerate `menu_search_cache` if you rely on cached search results (optional; the renderer rebuilds it on the fly if missing).

> **Important:** Do **not** run `shared-utilities/menu_data_loader.sh` until it has been rewritten for `menu_items_v2`. The current script truncates the old tables and repopulates the flat schema, erasing the hierarchical data.

## Known To-Do Items
- Map every `*_menu()` function to an actual submenu or rebuild the interactive loop so the associated routines are reachable from the UI.
- Create a new loader/migration tool that seeds `menu_items_v2` with parent-child relationships, icons, descriptions, and keywords.
- Remove or hide menu entries that point to unimplemented functions until the features are complete.
- Expand test coverage (`test_hierarchical_menu.sh`, `test_menu_rendering.sh`, etc.) to verify not only that items exist in the database, but that selecting them reaches the intended function.

## Testing Tips
- `./test_hierarchical_menu.sh` checks that `menu_items_v2` is populated, the recursive view works, and there are no orphaned or circular references (it does **not** execute menu actions).
- `./test_menu_rendering.sh` confirms each menu can be queried from SQLite without errors.
- Manual smoke tests are still required: run `./gwombat.sh`, navigate through menus, and confirm that the expected routines execute instead of looping back to the main screen.

Keep this document current whenever menu definitions or supporting scripts change so contributors know which parts of the refactor are stable and which still need implementation work.
