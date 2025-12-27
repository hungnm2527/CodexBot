<?php
/**
 * Theme setup.
 */

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

add_action( 'after_setup_theme', 'first_theme_setup' );
/**
 * Configure core theme supports and defaults.
 */
function first_theme_setup() {
	load_theme_textdomain( 'first-theme', get_template_directory() . '/languages' );

	add_theme_support( 'title-tag' );
	add_theme_support( 'post-thumbnails' );
	add_theme_support( 'html5', [ 'search-form', 'gallery', 'caption', 'style', 'script' ] );
	add_theme_support( 'custom-logo', [
		'height'      => 120,
		'width'       => 300,
		'flex-height' => true,
		'flex-width'  => true,
	] );
	add_theme_support( 'responsive-embeds' );

	register_nav_menus( [
		'primary' => __( 'Primary Menu', 'first-theme' ),
		'footer'  => __( 'Footer Menu', 'first-theme' ),
	] );
}
