<?php
/**
 * Enqueue scripts and styles.
 */

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

add_action( 'wp_enqueue_scripts', 'starter_theme_enqueue_assets' );
/**
 * Register theme styles and scripts.
 */
function starter_theme_enqueue_assets() {
	$theme_version = wp_get_theme()->get( 'Version' );
	$asset_path    = get_template_directory_uri();

	wp_enqueue_style( 'starter-theme-styles', $asset_path . '/assets/css/style.css', [], $theme_version );
	wp_enqueue_script( 'starter-theme-scripts', $asset_path . '/assets/js/main.js', [ 'jquery' ], $theme_version, true );
}
