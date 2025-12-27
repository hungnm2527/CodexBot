<?php
/* Template Name: Home */
get_header();

$featured_query = new WP_Query(
  [
    'posts_per_page'      => 3,
    'ignore_sticky_posts' => true,
    'meta_key'            => '_thumbnail_id',
  ]
);

$category_terms = get_categories(
  [
    'hide_empty' => false,
    'number'     => 6,
  ]
);
?>

<section class="hero-slider" aria-label="Featured stories">
  <p class="section-label"><?php esc_html_e( 'Slider', 'first-theme' ); ?></p>
  <div class="slider-window">
    <?php
    $slide_index = 0;
    if ( $featured_query->have_posts() ) :
      while ( $featured_query->have_posts() ) :
        $featured_query->the_post();
        $is_active = 0 === $slide_index ? ' is-active' : '';
        ?>
        <article class="slide<?php echo esc_attr( $is_active ); ?>" data-slide-index="<?php echo esc_attr( $slide_index ); ?>">
          <div class="slide__media">
            <?php
            if ( has_post_thumbnail() ) {
              the_post_thumbnail( 'large' );
            } else {
              echo '<div style="width:100%;height:100%;background:#e5e7eb;"></div>'; // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped
            }
            ?>
          </div>
          <div class="slide__content">
            <p class="section-label"><?php echo esc_html( get_the_category_list( ', ' ) ? __( 'Category', 'first-theme' ) : __( 'Featured', 'first-theme' ) ); ?></p>
            <h2><a href="<?php the_permalink(); ?>"><?php the_title(); ?></a></h2>
            <p><?php echo wp_kses_post( wp_trim_words( get_the_excerpt(), 26 ) ); ?></p>
            <div class="article-meta">
              <span><?php echo esc_html( get_the_date() ); ?></span>
              <span>&middot;</span>
              <span><?php echo esc_html( get_the_author() ); ?></span>
            </div>
          </div>
        </article>
        <?php
        $slide_index ++;
      endwhile;
      wp_reset_postdata();
    else :
      ?>
      <article class="slide is-active">
        <div class="slide__media"></div>
        <div class="slide__content">
          <p class="section-label"><?php esc_html_e( 'Featured', 'first-theme' ); ?></p>
          <h2><?php esc_html_e( 'Add your first post to see it here.', 'first-theme' ); ?></h2>
          <p><?php esc_html_e( 'Use this wide area to spotlight an important story or promotion.', 'first-theme' ); ?></p>
        </div>
      </article>
    <?php endif; ?>
  </div>
  <?php if ( $featured_query->found_posts > 1 ) : ?>
    <div class="slider-dots" role="tablist" aria-label="Slider pagination">
      <?php for ( $i = 0; $i < $featured_query->found_posts; $i++ ) : ?>
        <button type="button" class="<?php echo 0 === $i ? 'is-active' : ''; ?>" data-target-slide="<?php echo esc_attr( $i ); ?>">
          <span class="screen-reader-text"><?php printf( esc_html__( 'Show slide %d', 'first-theme' ), $i + 1 ); ?></span>
        </button>
      <?php endfor; ?>
    </div>
  <?php endif; ?>
</section>

<section aria-label="Categories">
  <div class="category-strip">
    <?php
    if ( $category_terms ) {
      foreach ( $category_terms as $cat ) {
        echo '<a class="category-tile" href="' . esc_url( get_category_link( $cat->term_id ) ) . '">' . esc_html( $cat->name ) . '</a>'; // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped
      }
    } else {
      for ( $i = 0; $i < 6; $i++ ) {
        echo '<span class="category-tile">' . esc_html__( 'Category', 'first-theme' ) . '</span>'; // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped
      }
    }
    ?>
  </div>
</section>

<section class="content-grid" aria-label="Content layout">
  <div>
    <p class="section-label"><?php esc_html_e( 'Latest Articles', 'first-theme' ); ?></p>
    <div class="article-list">
      <?php
      $posts_query = new WP_Query(
        [
          'posts_per_page' => 6,
        ]
      );

      if ( $posts_query->have_posts() ) :
        while ( $posts_query->have_posts() ) :
          $posts_query->the_post();
          ?>
          <article class="article-card">
            <div class="thumb">
              <a href="<?php the_permalink(); ?>">
                <?php
                if ( has_post_thumbnail() ) {
                  the_post_thumbnail( 'medium_large' );
                }
                ?>
              </a>
            </div>
            <div>
              <p class="section-label"><?php echo get_the_category_list( ', ' ); // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped ?></p>
              <h3><a href="<?php the_permalink(); ?>"><?php the_title(); ?></a></h3>
              <p><?php echo wp_kses_post( wp_trim_words( get_the_excerpt(), 26 ) ); ?></p>
              <div class="article-meta">
                <span><?php echo esc_html( get_the_date() ); ?></span>
                <span>&middot;</span>
                <span><?php echo esc_html( get_the_author() ); ?></span>
              </div>
            </div>
          </article>
          <?php
        endwhile;
        wp_reset_postdata();
      else :
        ?>
        <article class="article-card">
          <div class="thumb"></div>
          <div>
            <h3><?php esc_html_e( 'No posts yet', 'first-theme' ); ?></h3>
            <p><?php esc_html_e( 'Create a few posts to see them listed here with thumbnails and excerpts.', 'first-theme' ); ?></p>
          </div>
        </article>
      <?php endif; ?>
    </div>
  </div>

  <aside class="sidebar" aria-label="Sidebar">
    <div class="widget">
      <h4><?php esc_html_e( 'Latest posts', 'first-theme' ); ?></h4>
      <ul>
        <?php
        $latest_sidebar = new WP_Query(
          [
            'posts_per_page' => 5,
            'ignore_sticky_posts' => true,
          ]
        );
        if ( $latest_sidebar->have_posts() ) :
          while ( $latest_sidebar->have_posts() ) :
            $latest_sidebar->the_post();
            echo '<li><a href="' . esc_url( get_the_permalink() ) . '">' . esc_html( get_the_title() ) . '</a></li>'; // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped
          endwhile;
          wp_reset_postdata();
        else :
          echo '<li>' . esc_html__( 'No posts yet.', 'first-theme' ) . '</li>'; // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped
        endif;
        ?>
      </ul>
    </div>

    <div class="widget">
      <h4><?php esc_html_e( 'Featured posts', 'first-theme' ); ?></h4>
      <ul>
        <?php
        $featured_sidebar = new WP_Query(
          [
            'posts_per_page'      => 3,
            'post__in'            => get_option( 'sticky_posts' ),
            'ignore_sticky_posts' => false,
          ]
        );
        if ( $featured_sidebar->have_posts() ) :
          while ( $featured_sidebar->have_posts() ) :
            $featured_sidebar->the_post();
            echo '<li><a href="' . esc_url( get_the_permalink() ) . '">' . esc_html( get_the_title() ) . '</a></li>'; // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped
          endwhile;
          wp_reset_postdata();
        else :
          echo '<li>' . esc_html__( 'Mark a post as sticky to feature it.', 'first-theme' ) . '</li>'; // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped
        endif;
        ?>
      </ul>
    </div>

    <div class="widget">
      <h4><?php esc_html_e( 'Tag cloud', 'first-theme' ); ?></h4>
      <div class="tag-cloud">
        <?php
        $tags = wp_tag_cloud(
          [
            'smallest'  => 0.85,
            'largest'   => 1,
            'unit'      => 'rem',
            'format'    => 'array',
            'separator' => ' ',
            'echo'      => false,
          ]
        );

        if ( $tags ) {
          foreach ( $tags as $tag ) {
            echo $tag; // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped
          }
        } else {
          echo '<span>' . esc_html__( 'No tags yet', 'first-theme' ) . '</span>'; // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped
        }
        ?>
      </div>
    </div>
  </aside>
</section>
<?php
get_footer();
