<?php
if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

/**
 * Register Gutenberg block patterns.
 */
function fhbs_register_block_patterns() {
	if ( ! function_exists( 'register_block_pattern' ) ) {
		return;
	}

	register_block_pattern_category(
		'food-herb-blog',
		array(
			'label' => __( 'Food Herb Blog', 'food-herb-blog-setup' ),
		)
	);

	register_block_pattern(
		'fhbs-home-hero',
		array(
			'title'      => __( 'Home – Hero', 'food-herb-blog-setup' ),
			'categories' => array( 'food-herb-blog' ),
			'content'    => <<<HTML
<!-- wp:group {"style":{"spacing":{"padding":{"top":"60px","bottom":"60px","left":"20px","right":"20px"}}},"layout":{"type":"constrained"}} -->
<div class="wp-block-group" style="padding-top:60px;padding-right:20px;padding-bottom:60px;padding-left:20px"><!-- wp:heading {"textAlign":"center","level":1} -->
<h1 class="wp-block-heading has-text-align-center">Ăn ngon – Sống khoẻ cùng thảo mộc</h1>
<!-- /wp:heading -->

<!-- wp:paragraph {"align":"center","fontSize":"medium"} -->
<p class="has-text-align-center has-medium-font-size">Khám phá thực phẩm, dược liệu, trà thảo mộc và công thức kết hợp cho từng nhu cầu sức khỏe.</p>
<!-- /wp:paragraph -->

<!-- wp:buttons {"layout":{"type":"flex","justifyContent":"center"}} -->
<div class="wp-block-buttons"><!-- wp:button -->
<div class="wp-block-button"><a class="wp-block-button__link wp-element-button">Bắt đầu từ đây</a></div>
<!-- /wp:button -->

<!-- wp:button {"className":"is-style-outline"} -->
<div class="wp-block-button is-style-outline"><a class="wp-block-button__link wp-element-button">Theo nhu cầu</a></div>
<!-- /wp:button --></div>
<!-- /wp:buttons --></div>
<!-- /wp:group -->
HTML
		)
	);

	register_block_pattern(
		'fhbs-home-nhu-cau',
		array(
			'title'      => __( 'Home – Theo nhu cầu (6 ô)', 'food-herb-blog-setup' ),
			'categories' => array( 'food-herb-blog' ),
			'content'    => <<<HTML
<!-- wp:group {"layout":{"type":"constrained"}} -->
<div class="wp-block-group"><!-- wp:heading {"textAlign":"center"} -->
<h2 class="wp-block-heading has-text-align-center">Theo nhu cầu</h2>
<!-- /wp:heading -->

<!-- wp:columns {"columns":3} -->
<div class="wp-block-columns columns-3"><!-- wp:column -->
<div class="wp-block-column"><!-- wp:group {"style":{"border":{"width":"1px"},"spacing":{"padding":{"top":"16px","right":"16px","bottom":"16px","left":"16px"}}},"layout":{"type":"constrained"}} -->
<div class="wp-block-group" style="border-width:1px;padding-top:16px;padding-right:16px;padding-bottom:16px;padding-left:16px"><!-- wp:heading {"level":3} -->
<h3 class="wp-block-heading">Giảm cân</h3>
<!-- /wp:heading -->

<!-- wp:paragraph -->
<p>Thực đơn ít đường, giàu chất xơ.</p>
<!-- /wp:paragraph --></div>
<!-- /wp:group --></div>
<!-- /wp:column -->

<!-- wp:column -->
<div class="wp-block-column"><!-- wp:group {"style":{"border":{"width":"1px"},"spacing":{"padding":{"top":"16px","right":"16px","bottom":"16px","left":"16px"}}},"layout":{"type":"constrained"}} -->
<div class="wp-block-group" style="border-width:1px;padding-top:16px;padding-right:16px;padding-bottom:16px;padding-left:16px"><!-- wp:heading {"level":3} -->
<h3 class="wp-block-heading">Tiểu đường</h3>
<!-- /wp:heading -->

<!-- wp:paragraph -->
<p>Công thức low GI, kiểm soát đường huyết.</p>
<!-- /wp:paragraph --></div>
<!-- /wp:group --></div>
<!-- /wp:column -->

<!-- wp:column -->
<div class="wp-block-column"><!-- wp:group {"style":{"border":{"width":"1px"},"spacing":{"padding":{"top":"16px","right":"16px","bottom":"16px","left":"16px"}}},"layout":{"type":"constrained"}} -->
<div class="wp-block-group" style="border-width:1px;padding-top:16px;padding-right:16px;padding-bottom:16px;padding-left:16px"><!-- wp:heading {"level":3} -->
<h3 class="wp-block-heading">Dạ dày</h3>
<!-- /wp:heading -->

<!-- wp:paragraph -->
<p>Món ăn dịu nhẹ, tốt cho hệ tiêu hoá.</p>
<!-- /wp:paragraph --></div>
<!-- /wp:group --></div>
<!-- /wp:column --></div>
<!-- /wp:columns -->

<!-- wp:columns {"columns":3} -->
<div class="wp-block-columns columns-3"><!-- wp:column -->
<div class="wp-block-column"><!-- wp:group {"style":{"border":{"width":"1px"},"spacing":{"padding":{"top":"16px","right":"16px","bottom":"16px","left":"16px"}}},"layout":{"type":"constrained"}} -->
<div class="wp-block-group" style="border-width:1px;padding-top:16px;padding-right:16px;padding-bottom:16px;padding-left:16px"><!-- wp:heading {"level":3} -->
<h3 class="wp-block-heading">Mỡ máu – tim mạch</h3>
<!-- /wp:heading -->

<!-- wp:paragraph -->
<p>Thực phẩm tốt cho tim mạch, hạn chế chất béo xấu.</p>
<!-- /wp:paragraph --></div>
<!-- /wp:group --></div>
<!-- /wp:column -->

<!-- wp:column -->
<div class="wp-block-column"><!-- wp:group {"style":{"border":{"width":"1px"},"spacing":{"padding":{"top":"16px","right":"16px","bottom":"16px","left":"16px"}}},"layout":{"type":"constrained"}} -->
<div class="wp-block-group" style="border-width:1px;padding-top:16px;padding-right:16px;padding-bottom:16px;padding-left:16px"><!-- wp:heading {"level":3} -->
<h3 class="wp-block-heading">Gan</h3>
<!-- /wp:heading -->

<!-- wp:paragraph -->
<p>Gợi ý thực phẩm hỗ trợ giải độc, bảo vệ gan.</p>
<!-- /wp:paragraph --></div>
<!-- /wp:group --></div>
<!-- /wp:column -->

<!-- wp:column -->
<div class="wp-block-column"><!-- wp:group {"style":{"border":{"width":"1px"},"spacing":{"padding":{"top":"16px","right":"16px","bottom":"16px","left":"16px"}}},"layout":{"type":"constrained"}} -->
<div class="wp-block-group" style="border-width:1px;padding-top:16px;padding-right:16px;padding-bottom:16px;padding-left:16px"><!-- wp:heading {"level":3} -->
<h3 class="wp-block-heading">Gout</h3>
<!-- /wp:heading -->

<!-- wp:paragraph -->
<p>Thực đơn kiểm soát purin, giảm viêm khớp.</p>
<!-- /wp:paragraph --></div>
<!-- /wp:group --></div>
<!-- /wp:column --></div>
<!-- /wp:columns --></div>
<!-- /wp:group -->
HTML
		)
	);

	register_block_pattern(
		'fhbs-home-tra-nhanh',
		array(
			'title'      => __( 'Home – Tra nhanh (6 ô)', 'food-herb-blog-setup' ),
			'categories' => array( 'food-herb-blog' ),
			'content'    => <<<HTML
<!-- wp:group {"layout":{"type":"constrained"}} -->
<div class="wp-block-group"><!-- wp:heading {"textAlign":"center"} -->
<h2 class="wp-block-heading has-text-align-center">Tra nhanh</h2>
<!-- /wp:heading -->

<!-- wp:columns {"columns":3} -->
<div class="wp-block-columns columns-3"><!-- wp:column -->
<div class="wp-block-column"><!-- wp:heading {"level":3} -->
<h3 class="wp-block-heading">Tác dụng của...</h3>
<!-- /wp:heading -->

<!-- wp:paragraph -->
<p>Hiển thị bài viết hướng dẫn công dụng dược liệu.</p>
<!-- /wp:paragraph --></div>
<!-- /wp:column -->

<!-- wp:column -->
<div class="wp-block-column"><!-- wp:heading {"level":3} -->
<h3 class="wp-block-heading">Kỵ khi kết hợp...</h3>
<!-- /wp:heading -->

<!-- wp:paragraph -->
<p>Lưu ý tương tác thực phẩm, dược liệu cần tránh.</p>
<!-- /wp:paragraph --></div>
<!-- /wp:column -->

<!-- wp:column -->
<div class="wp-block-column"><!-- wp:heading {"level":3} -->
<h3 class="wp-block-heading">Trà thảo mộc...</h3>
<!-- /wp:heading -->

<!-- wp:paragraph -->
<p>Các loại trà hỗ trợ giấc ngủ, tiêu hoá, thanh nhiệt.</p>
<!-- /wp:paragraph --></div>
<!-- /wp:column --></div>
<!-- /wp:columns -->

<!-- wp:columns {"columns":3} -->
<div class="wp-block-columns columns-3"><!-- wp:column -->
<div class="wp-block-column"><!-- wp:paragraph -->
<p>Bài nổi bật 1 (placeholder)</p>
<!-- /wp:paragraph --></div>
<!-- /wp:column -->

<!-- wp:column -->
<div class="wp-block-column"><!-- wp:paragraph -->
<p>Bài nổi bật 2 (placeholder)</p>
<!-- /wp:paragraph --></div>
<!-- /wp:column -->

<!-- wp:column -->
<div class="wp-block-column"><!-- wp:paragraph -->
<p>Bài nổi bật 3 (placeholder)</p>
<!-- /wp:paragraph --></div>
<!-- /wp:column --></div>
<!-- /wp:columns --></div>
<!-- /wp:group -->
HTML
		)
	);

	register_block_pattern(
		'fhbs-home-recipes',
		array(
			'title'      => __( 'Home – Công thức nổi bật (Query Loop placeholder)', 'food-herb-blog-setup' ),
			'categories' => array( 'food-herb-blog' ),
			'content'    => <<<HTML
<!-- wp:group {"layout":{"type":"constrained"}} -->
<div class="wp-block-group"><!-- wp:heading {"textAlign":"center"} -->
<h2 class="wp-block-heading has-text-align-center">Công thức nổi bật</h2>
<!-- /wp:heading -->

<!-- wp:query {"query":{"perPage":3,"pages":0,"offset":0,"postType":"post","order":"desc","orderBy":"date"},"layout":{"type":"default"}} -->
<div class="wp-block-query"><!-- wp:post-template -->
<!-- wp:group {"style":{"border":{"width":"1px"},"spacing":{"padding":{"top":"16px","right":"16px","bottom":"16px","left":"16px"}}},"layout":{"type":"constrained"}} -->
<div class="wp-block-group" style="border-width:1px;padding-top:16px;padding-right:16px;padding-bottom:16px;padding-left:16px"><!-- wp:post-title {"level":3,"isLink":true} /-->

<!-- wp:post-excerpt /-->

<!-- wp:post-date /--></div>
<!-- /wp:group -->
<!-- /wp:post-template -->

<!-- wp:query-no-results -->
<!-- wp:paragraph -->
<p>Chưa có công thức nào, hãy thêm bài viết mới.</p>
<!-- /wp:paragraph -->
<!-- /wp:query-no-results --></div>
<!-- /wp:query --></div>
<!-- /wp:group -->
HTML
		)
	);

	register_block_pattern(
		'fhbs-home-review',
		array(
			'title'      => __( 'Home – Review & Gợi ý mua (Query Loop placeholder)', 'food-herb-blog-setup' ),
			'categories' => array( 'food-herb-blog' ),
			'content'    => <<<HTML
<!-- wp:group {"layout":{"type":"constrained"}} -->
<div class="wp-block-group"><!-- wp:heading {"textAlign":"center"} -->
<h2 class="wp-block-heading has-text-align-center">Review &amp; Gợi ý mua</h2>
<!-- /wp:heading -->

<!-- wp:query {"query":{"perPage":3,"pages":0,"offset":0,"postType":"post","order":"desc","orderBy":"date","taxQuery":[]},"layout":{"type":"default"}} -->
<div class="wp-block-query"><!-- wp:post-template -->
<!-- wp:group {"style":{"spacing":{"padding":{"top":"12px","right":"12px","bottom":"12px","left":"12px"}},"border":{"width":"1px"}},"layout":{"type":"constrained"}} -->
<div class="wp-block-group" style="border-width:1px;padding-top:12px;padding-right:12px;padding-bottom:12px;padding-left:12px"><!-- wp:post-title {"level":3,"isLink":true} /-->

<!-- wp:post-excerpt /-->

<!-- wp:paragraph {"fontSize":"small"} -->
<p class="has-small-font-size">Thêm callout affiliate hoặc ưu đãi.</p>
<!-- /wp:paragraph --></div>
<!-- /wp:group -->
<!-- /wp:post-template -->

<!-- wp:query-no-results -->
<!-- wp:paragraph -->
<p>Chưa có bài review nào, thêm bài và gắn category Review &amp; Gợi ý.</p>
<!-- /wp:paragraph -->
<!-- /wp:query-no-results --></div>
<!-- /wp:query --></div>
<!-- /wp:group -->
HTML
		)
	);

	register_block_pattern(
		'fhbs-home-optin',
		array(
			'title'      => __( 'Home – Email opt-in (placeholder form)', 'food-herb-blog-setup' ),
			'categories' => array( 'food-herb-blog' ),
			'content'    => <<<HTML
<!-- wp:group {"style":{"border":{"width":"1px"},"spacing":{"padding":{"top":"24px","right":"24px","bottom":"24px","left":"24px"}}},"layout":{"type":"constrained"}} -->
<div class="wp-block-group" style="border-width:1px;padding-top:24px;padding-right:24px;padding-bottom:24px;padding-left:24px"><!-- wp:heading {"textAlign":"center"} -->
<h2 class="wp-block-heading has-text-align-center">Nhận bài viết mới</h2>
<!-- /wp:heading -->

<!-- wp:paragraph {"align":"center"} -->
<p class="has-text-align-center">Đăng ký nhận mẹo dinh dưỡng, công thức và review sản phẩm uy tín.</p>
<!-- /wp:paragraph -->

<!-- wp:columns {"verticalAlignment":"center"} -->
<div class="wp-block-columns are-vertically-aligned-center"><!-- wp:column {"verticalAlignment":"center","width":"70%"} -->
<div class="wp-block-column is-vertically-aligned-center" style="flex-basis:70%"><!-- wp:paragraph -->
<p>Form placeholder: thêm block Form hoặc HTML tùy plugin/email service.</p>
<!-- /wp:paragraph --></div>
<!-- /wp:column -->

<!-- wp:column {"verticalAlignment":"center","width":"30%"} -->
<div class="wp-block-column is-vertically-aligned-center" style="flex-basis:30%"><!-- wp:button -->
<div class="wp-block-button"><a class="wp-block-button__link wp-element-button">Đăng ký</a></div>
<!-- /wp:button --></div>
<!-- /wp:column --></div>
<!-- /wp:columns --></div>
<!-- /wp:group -->
HTML
		)
	);
}
