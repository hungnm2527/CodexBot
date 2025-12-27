# WordPress Site

This directory contains a standalone WordPress project scaffold and the custom **First Theme** for the magazine-style homepage. It lives under `projects/wordpress/site` in the monorepo so you can work on the site independently from the MetaTrader code.

## Project structure
- `index.php` – entry point that boots WordPress.
- `.htaccess` – standard WordPress rewrite rules for pretty permalinks.
- `wp-config-sample.php` – configuration template; copy to `wp-config.php` and fill in credentials.
- `wp-admin/`, `wp-includes/` – core directories to be populated by the WordPress download step.
- `wp-content/` – user content and extensions (themes, plugins, uploads).
  - `themes/first-theme/` – custom magazine-style theme.
  - `plugins/` – place any site-specific plugins here.
  - `uploads/` – media uploads; contains an empty placeholder so the folder exists in git.
- `scripts/bootstrap-wordpress.sh` – helper to download the latest (or specific) WordPress core release while preserving `wp-content`.

## Getting started
1. **Download WordPress core**
   ```bash
   cd projects/wordpress/site
   ./scripts/bootstrap-wordpress.sh
   ```
   Set `WP_VERSION` if you need a specific release (e.g. `WP_VERSION=6.5.3 ./scripts/bootstrap-wordpress.sh`).

2. **Configure the site**
   - Copy `wp-config-sample.php` to `wp-config.php`, then update database credentials and salts. Generate salts from https://api.wordpress.org/secret-key/1.1/salt/.
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
