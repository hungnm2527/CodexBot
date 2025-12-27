<?php
/**
 * Plugin Name: Food & Herb Blog Setup
 * Description: Bootstrap a food-herb blog with pages, taxonomies, menus, reading settings, and block patterns.
 * Version: 1.0.0
 * Author: CodexBot
 */

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

define( 'FHBS_PLUGIN_VERSION', '1.0.0' );
define( 'FHBS_PLUGIN_DIR', plugin_dir_path( __FILE__ ) );
require_once FHBS_PLUGIN_DIR . 'includes/class-setup-runner.php';
require_once FHBS_PLUGIN_DIR . 'includes/block-patterns.php';

/**
 * Run setup tasks on activation.
 */
function fhbs_activate() {
	$runner = new FHBS_Setup_Runner();
	$runner->run();
	flush_rewrite_rules();
}
register_activation_hook( __FILE__, 'fhbs_activate' );

add_action( 'init', 'fhbs_register_block_patterns' );

add_action( 'admin_menu', 'fhbs_register_setup_page' );

/**
 * Register the setup page under Tools.
 */
function fhbs_register_setup_page() {
	add_management_page(
		__( 'Blog Setup', 'food-herb-blog-setup' ),
		__( 'Blog Setup', 'food-herb-blog-setup' ),
		'manage_options',
		'fhbs-blog-setup',
		'fhbs_render_setup_page'
	);
}

/**
 * Render the Blog Setup admin page.
 */
function fhbs_render_setup_page() {
	if ( ! current_user_can( 'manage_options' ) ) {
		return;
	}

	$log_messages = array();
	$nonce_action = 'fhbs_run_setup';

	if ( isset( $_POST['fhbs_run_setup'] ) && check_admin_referer( $nonce_action ) ) {
		$runner      = new FHBS_Setup_Runner();
		$log_messages = $runner->run();
		flush_rewrite_rules();
	}
	?>
	<div class="wrap">
		<h1><?php esc_html_e( 'Food & Herb Blog Setup', 'food-herb-blog-setup' ); ?></h1>
		<p><?php esc_html_e( 'Use this tool to create baseline pages, taxonomies, menus, and settings for your food and herb blog.', 'food-herb-blog-setup' ); ?></p>
		<form method="post">
			<?php wp_nonce_field( $nonce_action ); ?>
			<input type="hidden" name="fhbs_run_setup" value="1" />
			<?php submit_button( __( 'Run Setup', 'food-herb-blog-setup' ) ); ?>
		</form>
		<?php if ( ! empty( $log_messages ) ) : ?>
			<h2><?php esc_html_e( 'Setup Log', 'food-herb-blog-setup' ); ?></h2>
			<ul>
				<?php foreach ( $log_messages as $message ) : ?>
					<li><?php echo esc_html( $message ); ?></li>
				<?php endforeach; ?>
			</ul>
		<?php endif; ?>
	</div>
	<?php
}
