<?php
/* Template Name: About */
get_header();
?>
<section class="card">
  <?php if ( have_posts() ) : while ( have_posts() ) : the_post(); ?>
    <h1 class="section-title"><?php the_title(); ?></h1>
    <p class="section-subtitle"><?php esc_html_e( 'Share your mission, values, and story here.', 'starter-theme' ); ?></p>
    <div class="content">
      <?php the_content(); ?>
    </div>
  <?php endwhile; endif; ?>
</section>

<section class="grid grid-3">
  <article class="card">
    <h3><?php esc_html_e( 'Our mission', 'starter-theme' ); ?></h3>
    <p><?php esc_html_e( 'Explain the purpose that drives your work and the change you want to see.', 'starter-theme' ); ?></p>
  </article>
  <article class="card">
    <h3><?php esc_html_e( 'Our team', 'starter-theme' ); ?></h3>
    <p><?php esc_html_e( 'Introduce the people behind the brand to humanize your story.', 'starter-theme' ); ?></p>
  </article>
  <article class="card">
    <h3><?php esc_html_e( 'Our approach', 'starter-theme' ); ?></h3>
    <p><?php esc_html_e( 'Highlight how you work with clients or customers to achieve success.', 'starter-theme' ); ?></p>
  </article>
</section>
<?php
get_footer();
