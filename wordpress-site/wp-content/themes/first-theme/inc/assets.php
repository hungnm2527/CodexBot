<?php
/**
 * Enqueue scripts and styles.
 */

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

add_action( 'wp_enqueue_scripts', 'first_theme_enqueue_assets' );
/**
 * Register theme styles and scripts.
 */
function first_theme_enqueue_assets() {
	$theme_version = wp_get_theme()->get( 'Version' );
	$asset_path    = get_template_directory_uri();

	wp_enqueue_style( 'first-theme-styles', $asset_path . '/assets/css/style.css', [], $theme_version );
	wp_enqueue_script( 'first-theme-scripts', $asset_path . '/assets/js/main.js', [ 'jquery' ], $theme_version, true );
}
