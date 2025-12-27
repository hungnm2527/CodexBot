<?php
/**
 * Base WordPress configuration for this project.
 *
 * Copy database credentials into the placeholders below and update salts/keys using the WordPress.org secret-key service.
 *
 * @link https://wordpress.org/support/article/editing-wp-config-php/
 * @package WordPress
 */

// ** Database settings ** //
define( 'DB_NAME', 'your_database_name' );
define( 'DB_USER', 'your_database_user' );
define( 'DB_PASSWORD', 'your_database_password' );
define( 'DB_HOST', 'localhost' );

define( 'DB_CHARSET', 'utf8mb4' );
define( 'DB_COLLATE', '' );

// ** Authentication Unique Keys and Salts. ** //
// Generate unique phrases from https://api.wordpress.org/secret-key/1.1/salt/
define( 'AUTH_KEY',         'replace_with_unique_phrase' );
define( 'SECURE_AUTH_KEY',  'replace_with_unique_phrase' );
define( 'LOGGED_IN_KEY',    'replace_with_unique_phrase' );
define( 'NONCE_KEY',        'replace_with_unique_phrase' );
define( 'AUTH_SALT',        'replace_with_unique_phrase' );
define( 'SECURE_AUTH_SALT', 'replace_with_unique_phrase' );
define( 'LOGGED_IN_SALT',   'replace_with_unique_phrase' );
define( 'NONCE_SALT',       'replace_with_unique_phrase' );

// ** Site URLs ** //
// Optional: Uncomment and set the two lines below when deploying to a fixed domain.
// define( 'WP_HOME', 'https://example.com' );
// define( 'WP_SITEURL', 'https://example.com' );

$table_prefix = 'wp_';

// Enable debugging for local development.
define( 'WP_DEBUG', true );
define( 'WP_DEBUG_LOG', true );
define( 'WP_DEBUG_DISPLAY', false );

// Set up paths to load WordPress.
if ( ! defined( 'ABSPATH' ) ) {
    define( 'ABSPATH', __DIR__ . '/' );
}

require_once ABSPATH . 'wp-settings.php';
