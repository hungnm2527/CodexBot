<?php
/**
 * Customizer settings.
 */

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

add_action( 'customize_register', 'starter_theme_customize_register' );
/**
 * Register Customizer controls for homepage branding.
 *
 * @param WP_Customize_Manager $wp_customize Customizer instance.
 */
function starter_theme_customize_register( WP_Customize_Manager $wp_customize ) {
	$wp_customize->add_section( 'starter_theme_homepage', [
		'title'       => __( 'Homepage Settings', 'starter-theme' ),
		'priority'    => 30,
		'description' => __( 'Customize homepage logo and title.', 'starter-theme' ),
	] );

	$wp_customize->add_setting( 'starter_theme_home_logo', [
		'default'           => '',
		'transport'         => 'refresh',
		'sanitize_callback' => 'esc_url_raw',
	] );

	$wp_customize->add_control( new WP_Customize_Image_Control(
		$wp_customize,
		'starter_theme_home_logo_control',
		[
			'label'    => __( 'Homepage Logo', 'starter-theme' ),
			'section'  => 'starter_theme_homepage',
			'settings' => 'starter_theme_home_logo',
		]
	) );

	$wp_customize->add_setting( 'starter_theme_home_title', [
		'default'           => __( 'Welcome to Our Site', 'starter-theme' ),
		'transport'         => 'postMessage',
		'sanitize_callback' => 'sanitize_text_field',
	] );

	$wp_customize->add_control( 'starter_theme_home_title_control', [
		'label'       => __( 'Homepage Title', 'starter-theme' ),
		'section'     => 'starter_theme_homepage',
		'settings'    => 'starter_theme_home_title',
		'type'        => 'text',
		'input_attrs' => [
			'placeholder' => __( 'Enter homepage title', 'starter-theme' ),
		],
	] );

	if ( isset( $wp_customize->selective_refresh ) ) {
		$wp_customize->selective_refresh->add_partial( 'starter_theme_home_title', [
			'selector'        => '.hero__title',
			'render_callback' => 'starter_theme_render_home_title',
		] );
	}
}

/**
 * Render callback for selective refresh of homepage title.
 */
function starter_theme_render_home_title() {
	return esc_html( get_theme_mod( 'starter_theme_home_title', __( 'Welcome to Our Site', 'starter-theme' ) ) );
}

add_action( 'customize_preview_init', 'starter_theme_customize_preview_js' );
/**
 * Enqueue Customizer preview script.
 */
function starter_theme_customize_preview_js() {
	wp_enqueue_script(
		'starter-theme-customizer',
		get_template_directory_uri() . '/assets/js/customizer.js',
		[ 'customize-preview', 'jquery' ],
		wp_get_theme()->get( 'Version' ),
		true
	);
}
