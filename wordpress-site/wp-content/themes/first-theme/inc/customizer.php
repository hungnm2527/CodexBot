<?php
/**
 * Customizer settings.
 */

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

add_action( 'customize_register', 'first_theme_customize_register' );
/**
 * Register Customizer controls for homepage branding.
 *
 * @param WP_Customize_Manager $wp_customize Customizer instance.
 */
function first_theme_customize_register( WP_Customize_Manager $wp_customize ) {
	$wp_customize->add_section( 'first_theme_homepage', [
		'title'       => __( 'Homepage Settings', 'first-theme' ),
		'priority'    => 30,
		'description' => __( 'Customize homepage logo and title.', 'first-theme' ),
	] );

	$wp_customize->add_setting( 'first_theme_home_logo', [
		'default'           => '',
		'transport'         => 'refresh',
		'sanitize_callback' => 'esc_url_raw',
	] );

	$wp_customize->add_control( new WP_Customize_Image_Control(
		$wp_customize,
		'first_theme_home_logo_control',
		[
			'label'    => __( 'Homepage Logo', 'first-theme' ),
			'section'  => 'first_theme_homepage',
			'settings' => 'first_theme_home_logo',
		]
	) );

	$wp_customize->add_setting( 'first_theme_home_title', [
		'default'           => __( 'Welcome to Our Site', 'first-theme' ),
		'transport'         => 'postMessage',
		'sanitize_callback' => 'sanitize_text_field',
	] );

	$wp_customize->add_control( 'first_theme_home_title_control', [
		'label'       => __( 'Homepage Title', 'first-theme' ),
		'section'     => 'first_theme_homepage',
		'settings'    => 'first_theme_home_title',
		'type'        => 'text',
		'input_attrs' => [
			'placeholder' => __( 'Enter homepage title', 'first-theme' ),
		],
	] );

	if ( isset( $wp_customize->selective_refresh ) ) {
		$wp_customize->selective_refresh->add_partial( 'first_theme_home_title', [
			'selector'        => '.hero__title',
			'render_callback' => 'first_theme_render_home_title',
		] );
	}
}

/**
 * Render callback for selective refresh of homepage title.
 */
function first_theme_render_home_title() {
	return esc_html( get_theme_mod( 'first_theme_home_title', __( 'Welcome to Our Site', 'first-theme' ) ) );
}

add_action( 'customize_preview_init', 'first_theme_customize_preview_js' );
/**
 * Enqueue Customizer preview script.
 */
function first_theme_customize_preview_js() {
	wp_enqueue_script(
		'first-theme-customizer',
		get_template_directory_uri() . '/assets/js/customizer.js',
		[ 'customize-preview', 'jquery' ],
		wp_get_theme()->get( 'Version' ),
		true
	);
}
