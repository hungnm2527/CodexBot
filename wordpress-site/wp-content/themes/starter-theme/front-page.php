<?php
/* Template Name: Home */
get_header();
?>
<section class="hero">
  <div>
    <p class="eyebrow"><?php bloginfo( 'name' ); ?></p>
    <h1><?php esc_html_e( 'A flexible starter for your next WordPress project.', 'starter-theme' ); ?></h1>
    <p class="lead"><?php bloginfo( 'description' ); ?></p>
    <div class="cta">
      <a class="btn btn-primary" href="<?php echo esc_url( home_url( '/about' ) ); ?>"><?php esc_html_e( 'Learn more', 'starter-theme' ); ?></a>
      <a class="btn btn-secondary" href="<?php echo esc_url( home_url( '/contact' ) ); ?>"><?php esc_html_e( 'Contact us', 'starter-theme' ); ?></a>
    </div>
  </div>
  <div class="card">
    <h2 class="section-title"><?php esc_html_e( 'Quick highlights', 'starter-theme' ); ?></h2>
    <ul>
      <li><?php esc_html_e( 'Ready-to-use Home, About, and Contact templates.', 'starter-theme' ); ?></li>
      <li><?php esc_html_e( 'Responsive grid system with modern typography.', 'starter-theme' ); ?></li>
      <li><?php esc_html_e( 'Clean PHP templates for easy customization.', 'starter-theme' ); ?></li>
    </ul>
  </div>
</section>

<section class="grid grid-3" aria-label="Feature highlights">
  <article class="card">
    <h3><?php esc_html_e( 'Performance', 'starter-theme' ); ?></h3>
    <p><?php esc_html_e( 'Lean template files with minimal dependencies keep things fast.', 'starter-theme' ); ?></p>
  </article>
  <article class="card">
    <h3><?php esc_html_e( 'Accessibility', 'starter-theme' ); ?></h3>
    <p><?php esc_html_e( 'Semantic markup, focus styles, and keyboard-friendly navigation.', 'starter-theme' ); ?></p>
  </article>
  <article class="card">
    <h3><?php esc_html_e( 'Customization', 'starter-theme' ); ?></h3>
    <p><?php esc_html_e( 'Adjust colors, typography, and layout quickly with CSS variables.', 'starter-theme' ); ?></p>
  </article>
</section>

<section class="card">
  <h2 class="section-title"><?php esc_html_e( 'Latest posts', 'starter-theme' ); ?></h2>
  <?php
  $latest_posts = new WP_Query(
    [
      'posts_per_page' => 3,
    ]
  );
  ?>
  <?php if ( $latest_posts->have_posts() ) : ?>
    <div class="grid grid-3">
      <?php
      while ( $latest_posts->have_posts() ) :
        $latest_posts->the_post();
        ?>
        <article class="card">
          <h3><a href="<?php the_permalink(); ?>"><?php the_title(); ?></a></h3>
          <p><?php echo wp_kses_post( wp_trim_words( get_the_excerpt(), 20 ) ); ?></p>
          <a class="btn btn-secondary" href="<?php the_permalink(); ?>"><?php esc_html_e( 'Read more', 'starter-theme' ); ?></a>
        </article>
      <?php endwhile; ?>
    </div>
    <?php wp_reset_postdata(); ?>
  <?php else : ?>
    <p><?php esc_html_e( 'No recent posts yet—start publishing!', 'starter-theme' ); ?></p>
  <?php endif; ?>
</section>
<?php
get_footer();
