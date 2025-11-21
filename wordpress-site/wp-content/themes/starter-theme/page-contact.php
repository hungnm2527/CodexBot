<?php
/* Template Name: Contact */
get_header();
?>
<section class="card contact-card">
  <div>
    <h1 class="section-title"><?php the_title(); ?></h1>
    <p class="section-subtitle"><?php esc_html_e( 'We would love to hear from you. Fill out the form and we will respond soon.', 'starter-theme' ); ?></p>
    <div class="content">
      <?php the_content(); ?>
    </div>
  </div>
  <form class="card" method="post" action="mailto:contact@example.com">
    <div class="field">
      <label for="contact-name"><?php esc_html_e( 'Name', 'starter-theme' ); ?></label>
      <input id="contact-name" name="name" type="text" placeholder="<?php esc_attr_e( 'Jane Doe', 'starter-theme' ); ?>" required>
    </div>
    <div class="field">
      <label for="contact-email"><?php esc_html_e( 'Email', 'starter-theme' ); ?></label>
      <input id="contact-email" name="email" type="email" placeholder="name@example.com" required>
    </div>
    <div class="field">
      <label for="contact-message"><?php esc_html_e( 'Message', 'starter-theme' ); ?></label>
      <textarea id="contact-message" name="message" placeholder="<?php esc_attr_e( 'How can we help?', 'starter-theme' ); ?>" required></textarea>
    </div>
    <button class="btn btn-primary" type="submit"><?php esc_html_e( 'Send message', 'starter-theme' ); ?></button>
  </form>
</section>
<?php
get_footer();
