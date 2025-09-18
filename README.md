![GWOMBAT Logo](assets/gwombat2.png)

# GWOMBAT – Google Workspace Optimization, Management, Backups And Taskrunner

GWOMBAT is a large Bash-based operations toolkit for Google Workspace domains. It grew around a 24k-line primary script (`gwombat.sh`) plus dozens of shared utilities that automate user lifecycle tasks, shared drive management, reporting, and CSV exports. The current codebase is in the middle of a major refactor to a SQLite‑driven hierarchical menu system, so several entry points are still in flux.

## Project Snapshot (September 2025)
- Architecture: Bash 3.2+ scripts with SQLite for persistent state and menu metadata
- Dependencies: GAM (GAMADV-XTD3 recommended), sqlite3, git, optional Python 3.12+, GYB, rclone (see `docs/REQUIREMENTS.md`)
- Primary focus: User & group lifecycle tooling, domain data exports, shared drive administration, compliance workflows
- Current status: User & Group Management and core File & Drive Operations now load database-driven submenus, but several other sections still fall back to placeholder `render_menu` handlers and legacy Bash loops

## What Works Reliably Today
- **Domain inventory & lifecycle** – `sync_domain_to_database`, `rescan_all_accounts`, suspended-stage workflows, and bulk OU moves continue to function when their helper routines are called directly
- **CSV exports** – `shared-utilities/export_functions.sh` provides working commands for users, shared drives (`gam print shareddrives`), account lists, and storage summaries
- **Shared drive basics** – listing drives, creating drives, managing members, and drive diagnostics run correctly, though advanced analytics options are placeholders
- **Setup tooling** – `shared-utilities/setup_wizard.sh` still provisions `.env`, configures GAM/gyb/rclone, and seeds local directories; logs live under `local-config/logs/`

## Areas Needing Attention
- **Hierarchical menu conversion is ongoing** – key User & Group and File/Drive flows are now exposed through real `menu_items_v2` submenus, but other top-level sections (Dashboard, Reports, System Administration, SCuBA, Configuration) still point to placeholder `render_menu` handlers until their menus are rebuilt.
- **Legacy menu loader** – `shared-utilities/menu_data_loader.sh` still targets the legacy `menu_sections/menu_items` schema. Running it will overwrite the new `menu_items_v2` data and break the hierarchical menus.
- **Placeholder analytics/backup features** – functions like `login_activity_summary`, `drive_quick_search`, `backup_operations_function_dispatcher`, and many shared-drive reports still emit "Coming Soon" status. Keep them hidden from the database menus until production-ready.
- **Tests do not exercise behaviour** – `test_hierarchical_menu.sh` and related scripts confirm database structure, but they never drive real workflows, so regressions (like the looping menus) go undetected.

## Getting Started
1. **Clone** the repository and review the configuration templates:
   ```bash
   git clone git@github.com:mattbaya/gwombat.git
   cd gwombat
   cp .env-template local-config/.env  # optional shortcut; the wizard will create one if absent
   ```
2. **Install prerequisites** listed in `docs/REQUIREMENTS.md` (GAM, sqlite3, etc.).
3. **Run the setup wizard** to initialise `local-config/`, configure GAM, and seed required directories:
   ```bash
   ./shared-utilities/setup_wizard.sh
   ```
   The wizard logs to `local-config/logs/setup-*.log`.
4. **Launch GWOMBAT**:
   ```bash
   ./gwombat.sh
   ```
   The enhanced hierarchical UI loads by default. Because several menu entries route back to the same screen, you may need to invoke specific functions manually for now (see the note below).

> **Heads up:** until the menu wiring is repaired, you can work with the underlying routines by sourcing the script in an interactive shell:
> ```bash
> bash
> source gwombat.sh  # loads functions without starting the menu loop
> rescan_all_accounts
> bulk_ou_moves_from_csv
> ```
> Alternatively, set `USE_HIERARCHICAL_MENUS=false` before launching to exercise the remaining legacy flows, but expect the same looping behaviour for any function that was rewritten to simply call `render_menu`.

## Repository Layout
- `gwombat.sh` – main application (menu loop, orchestration, hundreds of helper routines)
- `shared-utilities/` – 70+ supporting scripts: database helpers, export utilities, setup wizard, hierarchical menu renderer, tests, workflow automation
- `shared-config/` – version-controlled configuration (SQLite databases, schema files, hierarchical menu definitions and backups)
- `local-config/` – instance-specific data created by the setup wizard; contains `.env`, `gwombat.db`, logs, reports, exports, backups (ignored by git)
- `docs/` – supplemental manuals (installation, deployment, menu architecture, troubleshooting)
- `logs/`, `reports/`, `assets/`, `python-modules/` – assorted supporting assets and optional integrations

## Documentation Map
- `docs/INSTALLATION.md` – end-to-end setup instructions (still applicable for prerequisites)
- `docs/HIERARCHICAL_MENU_SYSTEM.md` – current state of the menu refactor (now updated with known gaps)
- `docs/CSV_EXPORT_SYSTEM.md` – working export commands (`gam print shareddrives` etc.)
- `TESTING.md` / `docs/TESTING_PLAN.md` – QA expectations and security-focused testing checklist
- `TO-DO.md` – running backlog of enhancements and historical milestones
- `CLAUDE.md` – AI pair-programming context and technical notes for contributors
- `TODO_SESSION.md` – working list of outstanding menu-migration tasks from the current session

## Known Issues & Next Steps
- Expand the new hierarchical pattern to the remaining root menus (Dashboard, Reports, System Administration, SCuBA, Configuration), replacing the temporary `render_menu` placeholders with real submenu structures in `menu_items_v2`.
- Update `menu_data_loader.sh` (and related SQL) to populate `menu_items_v2` and preserve the hierarchical relationships. Consider archiving the legacy schema to avoid accidental reversion.
- Audit every menu entry whose implementation currently prints “Coming Soon” or “This feature will…”, decide whether to expose it as a planned feature or remove it from the live menu until complete.
- Expand automated tests beyond structural checks—smoke-test the main user workflows (`rescan_all_accounts`, `bulk_ou_moves_from_csv`, shared drive creation, CSV exports) so regressions are caught early.
- Refresh deployment and troubleshooting docs once the menu refactor stabilises; many passages still describe a fully functional hierarchical experience that does not yet exist.

## Testing & QA Reminders
- Basic syntax checks: `bash -n gwombat.sh` and `bash -n shared-utilities/*.sh`
- Menu structure verification: `./test_hierarchical_menu.sh` (confirms database integrity only)
- Manual regression: run `./gwombat.sh` and exercise critical workflows end-to-end, paying close attention to menu loops and error handling
- Security review material lives in `TESTING.md` and deliberately stresses adversarial scenarios—use it when hardening the system

## Contributing
- Keep secrets in `local-config/`; `.env-template` shows expected variables
- Review `TO-DO.md` and `CLAUDE.md` for current priorities and architectural guardrails (naming conventions, GAM syntax expectations)
- When touching database code, use `shared-utilities/database_functions.sh` helpers to benefit from the existing parameterisation and logging

GWOMBAT remains a powerful admin toolkit, but the ongoing menu migration means accuracy in documentation is critical. Please update relevant docs whenever functionality changes so operators know which paths are production-ready and which are still in progress.
