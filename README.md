# CodexBot Monorepo

This repository is a monorepo containing MetaTrader 5 (MT5) trading code and a WordPress site. See `INSTRUCTIONS_REPO_STRUCTURE.md` for the authoritative folder layout and contribution rules.

## Projects
- **MT5 trading code** (`projects/mt5/`): Expert Advisors and related assets. See `projects/mt5/README.md`.
- **WordPress site** (`projects/wordpress/site/`): Theme, plugins, and bootstrap scripts. See `projects/wordpress/site/README.md`.

## Documentation
- Shared docs live under `docs/` (architecture, runbooks, decisions).
- Project-specific docs can be found under each project’s `docs/` folder.

## Quick start
- **MT5**: Open the MT5 project in MetaEditor, copy the `experts/`, `scripts/`, `indicators/`, and `include/` folders into your platform’s `MQL5` directory to test locally.
- **WordPress**: From `projects/wordpress/site`, run `./scripts/bootstrap-wordpress.sh` to download WordPress core, then copy `wp-config-sample.php` to `wp-config.php` and fill in credentials.
