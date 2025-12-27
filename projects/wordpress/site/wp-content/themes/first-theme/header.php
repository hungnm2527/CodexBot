<!doctype html>
<html <?php language_attributes(); ?>>
<head>
  <meta charset="<?php bloginfo( 'charset' ); ?>">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <?php wp_head(); ?>
</head>
<body <?php body_class(); ?>>
<header>
  <div class="site-header">
    <a class="brand" href="<?php echo esc_url( home_url( '/' ) ); ?>">
      <span class="logo" aria-hidden="true">WP</span>
      <span class="brand-text"><?php bloginfo( 'name' ); ?></span>
    </a>
    <button class="nav-toggle" aria-expanded="false" aria-controls="primary-menu">Menu</button>
    <nav id="primary-menu" aria-label="Primary">
      <?php
      if ( has_nav_menu( 'primary' ) ) {
        wp_nav_menu(
          [
            'theme_location' => 'primary',
            'container'      => false,
            'menu_class'     => 'menu',
            'fallback_cb'    => false,
          ]
        );
      } else {
        echo '<ul>'; // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped
        wp_list_pages( [
          'title_li' => '',
          'depth'    => 1,
        ] );
        echo '</ul>'; // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped
      }
      ?>
    </nav>
  </div>
</header>
<main>
