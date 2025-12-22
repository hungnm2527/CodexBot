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
        $runner       = new FHBS_Setup_Runner();

        if ( isset( $_POST['fhbs_run_setup'] ) && check_admin_referer( $nonce_action ) ) {
                $log_messages = $runner->run();
                flush_rewrite_rules();
        }

        $category_status = $runner->get_category_status();
        $menu_overview   = $runner->get_menu_overview();
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

                <h2><?php esc_html_e( 'Quản lý Category', 'food-herb-blog-setup' ); ?></h2>
                <p><?php esc_html_e( 'Theo dõi nhanh trạng thái cây category và mở trang chỉnh sửa trong Admin.', 'food-herb-blog-setup' ); ?></p>
                <ul class="fhbs-category-status">
                        <?php fhbs_render_category_status_list( $category_status ); ?>
                </ul>
                <p>
                        <a class="button button-secondary" href="<?php echo esc_url( admin_url( 'edit-tags.php?taxonomy=category' ) ); ?>">
                                <?php esc_html_e( 'Mở trang quản lý Category', 'food-herb-blog-setup' ); ?>
                        </a>
                </p>

                <h2><?php esc_html_e( 'Quản lý Menu', 'food-herb-blog-setup' ); ?></h2>
                <?php if ( $menu_overview['exists'] ) : ?>
                        <p>
                                <?php
                                printf(
                                        /* translators: 1: menu name, 2: menu id */
                                        esc_html__( 'Menu "%1$s" đã tồn tại (ID %2$d).', 'food-herb-blog-setup' ),
                                        esc_html( $menu_overview['name'] ),
                                        (int) $menu_overview['menu_id']
                                );
                                ?>
                        </p>
                        <p>
                                <?php
                                if ( $menu_overview['is_primary_assigned'] ) {
                                        esc_html_e( 'Đã gán vào vị trí primary của theme.', 'food-herb-blog-setup' );
                                } elseif ( $menu_overview['primary_location_available'] ) {
                                        esc_html_e( 'Chưa gán vào vị trí primary của theme.', 'food-herb-blog-setup' );
                                } else {
                                        esc_html_e( 'Theme không khai báo vị trí primary; hãy gán thủ công nếu cần.', 'food-herb-blog-setup' );
                                }
                                ?>
                        </p>
                        <?php if ( ! empty( $menu_overview['top_level_items'] ) ) : ?>
                                <p>
                                        <?php esc_html_e( 'Mục cấp 1 hiện tại:', 'food-herb-blog-setup' ); ?>
                                        <strong>
                                        <?php
                                        $top_items = array_map( 'wp_strip_all_tags', $menu_overview['top_level_items'] );
                                        echo esc_html( implode( ', ', $top_items ) );
                                        ?>
                                        </strong>
                                </p>
                        <?php endif; ?>
                <?php else : ?>
                        <p><?php esc_html_e( 'Menu chưa được tạo. Bấm Run Setup để dựng menu mặc định.', 'food-herb-blog-setup' ); ?></p>
                <?php endif; ?>
                <p>
                        <a class="button button-secondary" href="<?php echo esc_url( $menu_overview['edit_url'] ); ?>">
                                <?php esc_html_e( 'Mở trình quản lý Menu', 'food-herb-blog-setup' ); ?>
                        </a>
                </p>
        </div>
        <?php
}

/**
 * Render nested category status list.
 *
 * @param array $categories Category status data.
 */
function fhbs_render_category_status_list( $categories ) {
        foreach ( $categories as $category ) {
                ?>
                <li>
                        <strong><?php echo esc_html( $category['name'] ); ?></strong>
                        <?php if ( $category['exists'] ) : ?>
                                — <?php esc_html_e( 'Đã tồn tại', 'food-herb-blog-setup' ); ?>
                                <?php if ( $category['term_id'] ) : ?>
                                        (ID <?php echo (int) $category['term_id']; ?>)
                                <?php endif; ?>
                                <?php if ( $category['edit_link'] ) : ?>
                                        <a href="<?php echo esc_url( $category['edit_link'] ); ?>"><?php esc_html_e( 'Chỉnh sửa', 'food-herb-blog-setup' ); ?></a>
                                <?php endif; ?>
                        <?php else : ?>
                                — <?php esc_html_e( 'Chưa được tạo', 'food-herb-blog-setup' ); ?>
                        <?php endif; ?>

                        <?php if ( ! empty( $category['children'] ) ) : ?>
                                <ul>
                                        <?php fhbs_render_category_status_list( $category['children'] ); ?>
                                </ul>
                        <?php endif; ?>
                </li>
                <?php
        }
}
