# Wordpress Site

This directory contains the standalone WordPress project and custom starter theme for the magazine-style homepage. It is isolated from the other trading-related files in the repository so you can work on the site independently.

## Getting started
1. Install WordPress in this folder (or point an existing local WordPress install to use `wp-content` here).
2. Activate the **Starter Theme** from the WordPress admin.
3. Assign the **Home** template to your front page to see the magazine layout with hero slider, category strip, article list, and sidebar widgets.

## Structure
- `wp-content/themes/starter-theme/` – theme templates, styles, and scripts
- `wp-content/plugins/` – place any site-specific plugins here if needed

Keeping the WordPress site here ensures it stays separate from the unrelated MetaTrader EA code in the repository root.
