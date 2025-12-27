<?php
get_header();
?>
<section class="card">
  <?php if ( have_posts() ) : while ( have_posts() ) : the_post(); ?>
    <h1 class="section-title"><?php the_title(); ?></h1>
    <div class="content">
      <?php the_content(); ?>
    </div>
  <?php endwhile; endif; ?>
</section>
<?php
get_footer();
