<?php
/**
 * Admin area enhancements and hardening.
 */

if ( ! defined( 'ABSPATH' ) ) {
        exit;
}

add_action( 'admin_init', 'starter_theme_admin_hardening' );
/**
 * Apply lightweight security settings for the admin area.
 */
function starter_theme_admin_hardening() {
        if ( ! defined( 'DISALLOW_FILE_EDIT' ) ) {
                define( 'DISALLOW_FILE_EDIT', true );
        }
}

add_action( 'admin_menu', 'starter_theme_customize_admin_menu' );
/**
 * Clean up admin menu entries that are not commonly used for brochure sites.
 */
function starter_theme_customize_admin_menu() {
        remove_menu_page( 'edit-comments.php' );
}

add_action( 'wp_dashboard_setup', 'starter_theme_register_dashboard_widget' );
/**
 * Register a dashboard widget with quick links for editors.
 */
function starter_theme_register_dashboard_widget() {
        wp_add_dashboard_widget(
                'starter_theme_dashboard_widget',
                __( 'Site quick actions', 'starter-theme' ),
                'starter_theme_render_dashboard_widget'
        );
}

/**
 * Render the dashboard widget content.
 */
function starter_theme_render_dashboard_widget() {
        ?>
        <p><?php esc_html_e( 'Handy shortcuts for keeping content fresh.', 'starter-theme' ); ?></p>
        <ul>
                <li><a href="<?php echo esc_url( admin_url( 'customize.php' ) ); ?>"><?php esc_html_e( 'Open Customizer', 'starter-theme' ); ?></a></li>
                <li><a href="<?php echo esc_url( admin_url( 'edit.php?post_type=page' ) ); ?>"><?php esc_html_e( 'Manage Pages', 'starter-theme' ); ?></a></li>
                <li><a href="<?php echo esc_url( admin_url( 'nav-menus.php' ) ); ?>"><?php esc_html_e( 'Update Navigation', 'starter-theme' ); ?></a></li>
        </ul>
        <?php
}

add_filter( 'admin_footer_text', 'starter_theme_admin_footer_text' );
/**
 * Provide a short, branded footer message in wp-admin.
 *
 * @param string $footer_text Original footer text.
 *
 * @return string
 */
function starter_theme_admin_footer_text( $footer_text ) {
        $footer_link = sprintf(
                '<a href="%1$s" target="_blank" rel="noopener">%2$s</a>',
                esc_url( home_url() ),
                esc_html( get_bloginfo( 'name' ) )
        );

        return sprintf(
                /* translators: %s: site name */
                __( 'Managed with care for %s.', 'starter-theme' ),
                $footer_link
        );
}

add_action( 'login_enqueue_scripts', 'starter_theme_login_branding' );
/**
 * Apply simple branding to the login screen.
 */
function starter_theme_login_branding() {
        $custom_logo_id = get_theme_mod( 'custom_logo' );
        $logo_data      = $custom_logo_id ? wp_get_attachment_image_src( $custom_logo_id, 'full' ) : false;
        $logo_url       = is_array( $logo_data ) ? $logo_data[0] : '';

        if ( ! $logo_url ) {
                $logo_url = get_theme_mod( 'starter_theme_home_logo' );
        }

        $logo_css = $logo_url ? sprintf( 'background-image:url(%s);', esc_url( $logo_url ) ) : '';
        ?>
        <style>
                body.login {
                        background: #f5f7fb;
                }

                .login h1 a {
                        <?php echo esc_html( $logo_css ); ?>
                        background-size: contain;
                        width: 100%;
                        height: 90px;
                        margin-bottom: 12px;
                }

                .login form {
                        border: 1px solid #dfe3eb;
                        box-shadow: 0 8px 30px rgba(0, 0, 0, 0.05);
                        border-radius: 10px;
                }

                .login #backtoblog a,
                .login #nav a {
                        color: #1d2327;
                }

                .login .button-primary {
                        background: #0073aa;
                        border-color: #006799;
                        box-shadow: none;
                        transition: background-color 0.2s ease;
                }

                .login .button-primary:hover,
                .login .button-primary:focus {
                        background: #006799;
                        border-color: #005e8c;
                }
        </style>
        <?php
}

add_filter( 'login_headerurl', 'starter_theme_login_url' );
/**
 * Point login logo to the site homepage.
 */
function starter_theme_login_url() {
        return home_url();
}

add_filter( 'login_headertext', 'starter_theme_login_title' );
/**
 * Update login logo title attribute.
 */
function starter_theme_login_title() {
        return get_bloginfo( 'name' );
}
