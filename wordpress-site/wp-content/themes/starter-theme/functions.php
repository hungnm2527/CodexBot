<?php
/**
 * Starter Theme setup.
 */

if ( ! defined( 'ABSPATH' ) ) {
  exit;
}

add_action( 'after_setup_theme', 'starter_theme_setup' );
function starter_theme_setup() {
  add_theme_support( 'title-tag' );
  add_theme_support( 'post-thumbnails' );
  add_theme_support( 'html5', [ 'search-form', 'gallery', 'caption', 'style', 'script' ] );

  register_nav_menus( [
    'primary' => __( 'Primary Menu', 'starter-theme' ),
    'footer'  => __( 'Footer Menu', 'starter-theme' ),
  ] );
}

add_action( 'wp_enqueue_scripts', 'starter_theme_assets' );
function starter_theme_assets() {
  $theme_version = wp_get_theme()->get( 'Version' );
  $asset_path    = get_template_directory_uri();

  wp_enqueue_style( 'starter-theme-styles', $asset_path . '/assets/css/style.css', [], $theme_version );
  wp_enqueue_script( 'starter-theme-scripts', $asset_path . '/assets/js/main.js', [], $theme_version, true );
}

add_filter( 'excerpt_more', '__return_empty_string' );
