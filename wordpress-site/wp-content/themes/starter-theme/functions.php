<?php
/**
 * Starter Theme bootstrap file.
 */

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

require get_template_directory() . '/inc/setup.php';
require get_template_directory() . '/inc/assets.php';
require get_template_directory() . '/inc/customizer.php';

add_filter( 'excerpt_more', '__return_empty_string' );
