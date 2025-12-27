<?php
get_header();
?>
<section class="card">
  <h1 class="section-title"><?php esc_html_e( 'Latest posts', 'first-theme' ); ?></h1>
  <?php if ( have_posts() ) : ?>
    <div class="grid grid-3">
      <?php while ( have_posts() ) : the_post(); ?>
        <article class="card">
          <?php if ( has_post_thumbnail() ) : ?>
            <a href="<?php the_permalink(); ?>"><?php the_post_thumbnail( 'medium_large' ); ?></a>
          <?php endif; ?>
          <h2><a href="<?php the_permalink(); ?>"><?php the_title(); ?></a></h2>
          <p><?php echo wp_kses_post( wp_trim_words( get_the_excerpt(), 24 ) ); ?></p>
          <a class="btn btn-secondary" href="<?php the_permalink(); ?>"><?php esc_html_e( 'Read more', 'first-theme' ); ?></a>
        </article>
      <?php endwhile; ?>
    </div>
    <?php the_posts_pagination(); ?>
  <?php else : ?>
    <p><?php esc_html_e( 'No posts found.', 'first-theme' ); ?></p>
  <?php endif; ?>
</section>
<?php
get_footer();
