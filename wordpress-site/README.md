# Wordpress Site

This directory contains a standalone WordPress project scaffold and the custom **First Theme** for the magazine-style homepage. It is isolated from the other trading-related files in the repository so you can work on the site independently.

## Project structure
- `index.php` – entry point that boots WordPress.
- `.htaccess` – standard WordPress rewrite rules for pretty permalinks.
- `wp-config.php` – configuration file with placeholders for database credentials and salts.
- `wp-admin/`, `wp-includes/` – core directories to be populated by the WordPress download step.
- `wp-content/` – user content and extensions (themes, plugins, uploads).
  - `themes/first-theme/` – custom magazine-style theme.
  - `plugins/` – place any site-specific plugins here.
  - `uploads/` – media uploads; contains an empty placeholder so the folder exists in git.
- `scripts/bootstrap-wordpress.sh` – helper to download the latest (or specific) WordPress core release while preserving `wp-content`.

## Getting started
1. **Download WordPress core**
   ```bash
   cd wordpress-site
   ./scripts/bootstrap-wordpress.sh
   ```
   Set `WP_VERSION` if you need a specific release (e.g. `WP_VERSION=6.5.3 ./scripts/bootstrap-wordpress.sh`).

2. **Configure the site**
   - Update database credentials and salts in `wp-config.php`. Generate salts from https://api.wordpress.org/secret-key/1.1/salt/.
   - Optionally set `WP_HOME` and `WP_SITEURL` when deploying to a fixed domain.

3. **File permissions**
   - Directories: `find . -type d -exec chmod 755 {} \;`
   - Files: `find . -type f -exec chmod 644 {} \;`
   - Ensure the web server user can write to `wp-content/uploads` (and `wp-content` during updates if needed).

4. **Enable pretty permalinks**
   - The bundled `.htaccess` contains the default Apache rewrite rules. For IIS, replace with `web.config` using equivalent rules.

5. **Run WordPress**
   - Point your web server document root to this folder.
   - Complete the web-based installer at `/wp-admin/install.php` after configuring the database.

## Additional notes
- Activate the **First Theme** from the WordPress admin and assign the **Home** template to your front page to see the magazine layout with hero slider, category strip, article list, and sidebar widgets.
- Keep the WordPress site here to ensure it stays separate from the unrelated MetaTrader EA code in the repository root.
