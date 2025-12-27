# Monorepo structure and contribution rules

This repository is organized as a monorepo containing the MetaTrader 5 (MT5) assets and a WordPress site. Use this file as the source of truth for where new files belong and what must be kept out of version control.

## Folder map (high level)
```
/
├─ README.md
├─ INSTRUCTIONS_REPO_STRUCTURE.md
├─ docs/
│  ├─ architecture/
│  ├─ decisions/
│  └─ runbooks/
├─ tools/
│  ├─ scripts/
│  └─ ci/
├─ projects/
│  ├─ mt5/
│  │  ├─ experts/
│  │  ├─ indicators/
│  │  ├─ scripts/
│  │  ├─ include/
│  │  ├─ profiles/
│  │  ├─ tester/
│  │  ├─ build/
│  │  └─ docs/
│  └─ wordpress/
│     ├─ site/
│     │  ├─ wp-admin/
│     │  ├─ wp-content/
│     │  │  ├─ themes/
│     │  │  ├─ plugins/
│     │  │  └─ uploads/ (placeholder only)
│     │  ├─ wp-includes/
│     │  ├─ wp-config-sample.php
│     │  └─ scripts/
│     └─ docs/
├─ archive/
│  ├─ incoming/
│  └─ legacy/
└─ misc/
   └─ tmp/
```

## Placement rules
- **MT5**: Place EAs in `projects/mt5/experts/`, indicators in `projects/mt5/indicators/`, scripts in `projects/mt5/scripts/`, and shared headers in `projects/mt5/include/`. Testing artifacts go to `projects/mt5/tester/`. Exported builds belong in `projects/mt5/build/` (but do not commit compiled `.ex5`).
- **WordPress**: All site assets belong under `projects/wordpress/site`. Themes go to `wp-content/themes/`, plugins to `wp-content/plugins/`, and uploads stay in `wp-content/uploads/` but should not be committed (use the placeholder). Bootstrap scripts and tooling belong in `projects/wordpress/site/scripts/`.
- **Docs**: Architecture/diagrams in `docs/architecture/`, operational runbooks in `docs/runbooks/`, and decision records in `docs/decisions/`. Project-specific docs can live under each project’s `docs/` folder.
- **Tooling & CI**: Shared scripts in `tools/scripts/` and CI/CD configs in `tools/ci/`.
- **Archive**: Unknown, legacy, or deprecated assets go to `archive/legacy/`. Staging/triage uploads go to `archive/incoming/` with a short note if the purpose is unclear.
- **Misc**: Temporary scratch items that are safe to delete live in `misc/tmp/`.

## Naming conventions
- MT5 files should use PascalCase (e.g., `MeanReversionEA.mq5`) and keep related headers in `include/`.
- WordPress themes/plugins should be lowercase with hyphens (e.g., `first-theme`, `food-herb-blog-setup`).
- Docs use clear, descriptive filenames (e.g., `data-flow.md`, `release-runbook.md`).

## What must **not** be committed
- Secrets or environment files (`wp-config.php` with real credentials, `.env`, API keys).
- Compiled MT5 artifacts (`*.ex5`, `*.ex4`, `.mqproj`).
- Generated/vendor directories (`vendor/`, `node_modules/`, `wp-content/uploads/`, caches).
- Logs and temporary files (`*.log`, `*.tmp`, editor swap files).

## Adding new work
- **New MT5 EA/indicator/script**: Place the source in the correct subfolder of `projects/mt5/`, keep shared code in `include/`, and document usage/build steps in `projects/mt5/docs/` or the project README.
- **New WordPress theme/plugin**: Add it under `projects/wordpress/site/wp-content/themes/` or `.../plugins/`. If it needs build tooling, keep those scripts within the theme/plugin or under `projects/wordpress/site/scripts/` and document them in the WordPress README.
- **Docs/decisions**: Add decision records to `docs/decisions/` and link them from relevant project docs when applicable.

## Build/run guidance (summary)
- **MT5**: Open `projects/mt5/` in MetaEditor. Copy the `experts/`, `indicators/`, `scripts/`, and `include/` contents into your platform’s `MQL5` directory when testing. Compiled output should go to `projects/mt5/build/` locally but remain untracked.
- **WordPress**: From `projects/wordpress/site`, run `./scripts/bootstrap-wordpress.sh` to download core while preserving `wp-content/`. Copy `wp-config-sample.php` to `wp-config.php` with local credentials. Keep uploads outside git; use the placeholder folder in commits.

## Versioning notes
- Prefer `git mv` for reorganizations to preserve history.
- If a file’s purpose is unclear, move it to `archive/incoming/` with a brief README note until clarified.
