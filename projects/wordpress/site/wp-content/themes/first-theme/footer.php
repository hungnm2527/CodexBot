</main>
<footer>
  <div class="footer-inner">
    <div>&copy; <?php echo esc_html( date_i18n( 'Y' ) ); ?> <?php bloginfo( 'name' ); ?>. Crafted with care.</div>
    <div class="footer-nav">
      <?php
      wp_nav_menu(
        [
          'theme_location' => 'footer',
          'container'      => false,
          'menu_class'     => 'footer-menu',
          'fallback_cb'    => false,
          'depth'          => 1,
        ]
      );
      ?>
    </div>
  </div>
</footer>
<?php wp_footer(); ?>
</body>
</html>
