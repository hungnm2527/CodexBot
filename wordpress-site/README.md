# Starter WordPress Site

This folder contains a lightweight WordPress theme and structure you can drop into a fresh WordPress installation. It sets up navigation, essential page templates (home, about, contact), and a clean design ready for customization.

## Getting started
1. Copy the `wp-content/themes/starter-theme` folder into the `wp-content/themes` directory of your WordPress installation.
2. Activate **Starter Theme** from the WordPress admin under **Appearance → Themes**.
3. Create pages named **Home**, **About**, and **Contact**, and assign the **Home** page as the "Homepage" under **Settings → Reading**.
4. Assign the **Primary Menu** location under **Appearance → Menus** (a sample fallback menu appears if none is assigned).

## Development notes
- Styles and scripts are enqueued from `assets/css/style.css` and `assets/js/main.js`.
- Page templates (`front-page.php`, `page-about.php`, `page-contact.php`) provide starter layouts you can edit or extend.
- The theme uses semantic HTML, accessible navigation, and responsive breakpoints for a smooth base experience.
