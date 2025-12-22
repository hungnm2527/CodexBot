<?php
if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

class FHBS_Setup_Runner {
	/**
	 * Store created page IDs keyed by slug.
	 *
	 * @var array
	 */
	private $page_ids = array();

	/**
	 * Store created category IDs keyed by slug.
	 *
	 * @var array
	 */
	private $category_ids = array();

	/**
	 * Execute all setup tasks.
	 *
	 * @return array
	 */
	public function run() {
		$log = array();

		$log = array_merge( $log, $this->create_pages() );
		$log = array_merge( $log, $this->create_categories() );
		$log = array_merge( $log, $this->create_tags() );
		$log = array_merge( $log, $this->create_menu() );
		$log = array_merge( $log, $this->set_reading_settings() );
		$log = array_merge( $log, $this->set_permalinks() );

		return $log;
	}

	/**
	 * Create baseline pages.
	 *
	 * @return array
	 */
	private function create_pages() {
		$pages = array(
			'home'                 => array(
				'title'   => __( 'Trang chủ', 'food-herb-blog-setup' ),
				'content' => $this->get_home_content(),
			),
			'bat-dau-tu-day'       => array(
				'title'   => __( 'Bắt đầu từ đây', 'food-herb-blog-setup' ),
				'content' => $this->get_getting_started_content(),
			),
			'thu-vien-kien-thuc'   => array(
				'title'   => __( 'Thư viện kiến thức', 'food-herb-blog-setup' ),
				'content' => $this->get_knowledge_library_content(),
			),
			'tra-nhanh'            => array(
				'title'   => __( 'Tra nhanh', 'food-herb-blog-setup' ),
				'content' => $this->get_quick_lookup_content(),
			),
			'review-goi-y-mua'     => array(
				'title'   => __( 'Review & Gợi ý mua', 'food-herb-blog-setup' ),
				'content' => $this->get_review_content(),
			),
			'disclaimer-suc-khoe'  => array(
				'title'   => __( 'Disclaimer sức khỏe', 'food-herb-blog-setup' ),
				'content' => $this->get_disclaimer_content(),
			),
			'chinh-sach-affiliate' => array(
				'title'   => __( 'Chính sách affiliate / Minh bạch', 'food-herb-blog-setup' ),
				'content' => $this->get_affiliate_policy_content(),
			),
			'lien-he'              => array(
				'title'   => __( 'Liên hệ', 'food-herb-blog-setup' ),
				'content' => $this->get_contact_content(),
			),
			'blog'                 => array(
				'title'   => __( 'Blog', 'food-herb-blog-setup' ),
				'content' => $this->get_blog_placeholder(),
			),
		);

		$log = array();

		foreach ( $pages as $slug => $page ) {
			$existing = get_page_by_path( $slug );

			if ( $existing ) {
				$this->page_ids[ $slug ] = (int) $existing->ID;
				$log[]                   = sprintf( __( 'Page "%1$s" already exists (ID %2$d).', 'food-herb-blog-setup' ), $page['title'], (int) $existing->ID );
				continue;
			}

			$page_id = wp_insert_post(
				array(
					'post_title'   => wp_strip_all_tags( $page['title'] ),
					'post_name'    => sanitize_title( $slug ),
					'post_content' => $page['content'],
					'post_status'  => 'publish',
					'post_type'    => 'page',
				)
			);

			if ( $page_id && ! is_wp_error( $page_id ) ) {
				$this->page_ids[ $slug ] = (int) $page_id;
				$log[]                   = sprintf( __( 'Created page "%1$s" (ID %2$d).', 'food-herb-blog-setup' ), $page['title'], (int) $page_id );
			} else {
				$log[] = sprintf( __( 'Failed to create page "%s".', 'food-herb-blog-setup' ), $page['title'] );
			}
		}

		return $log;
	}

	/**
	 * Create categories with parent/child relationships.
	 *
	 * @return array
	 */
        private function create_categories() {
                $log = array();

                foreach ( $this->get_category_structures() as $category ) {
                        $log = array_merge( $log, $this->create_category_branch( $category ) );
                }

                return $log;
        }

        /**
         * Get the predefined category structures.
         *
         * @return array
         */
        private function get_category_structures() {
                return array(
                        array(
                                'name'     => 'Thực phẩm',
                                'slug'     => 'thuc-pham',
                                'children' => array(
                                        array( 'name' => 'Trái cây', 'slug' => 'trai-cay' ),
                                        array( 'name' => 'Rau củ', 'slug' => 'rau-cu' ),
                                        array( 'name' => 'Ngũ cốc – hạt', 'slug' => 'ngu-coc-hat' ),
                                        array( 'name' => 'Gia vị', 'slug' => 'gia-vi' ),
                                        array( 'name' => 'Đồ uống', 'slug' => 'do-uong' ),
                                ),
                        ),
                        array(
                                'name'     => 'Dược liệu – thảo mộc',
                                'slug'     => 'duoc-lieu-thao-moc',
                                'children' => array(
                                        array( 'name' => 'Dược liệu phổ biến', 'slug' => 'duoc-lieu-pho-bien' ),
                                        array( 'name' => 'Cách dùng – bảo quản', 'slug' => 'cach-dung-bao-quan' ),
                                        array( 'name' => 'Lưu ý – chống chỉ định', 'slug' => 'luu-y-chong-chi-dinh' ),
                                ),
                        ),
                        array(
                                'name'     => 'Trà & thức uống thảo mộc',
                                'slug'     => 'tra-thuc-uong-thao-moc',
                                'children' => array(
                                        array( 'name' => 'Trà tiêu hoá', 'slug' => 'tra-tieu-hoa' ),
                                        array( 'name' => 'Trà ngủ ngon', 'slug' => 'tra-ngu-ngon' ),
                                        array( 'name' => 'Trà thanh nhiệt', 'slug' => 'tra-thanh-nhiet' ),
                                        array( 'name' => 'Trà hỗ trợ giảm cân', 'slug' => 'tra-ho-tro-giam-can' ),
                                ),
                        ),
                        array(
                                'name'     => 'Công thức',
                                'slug'     => 'cong-thuc',
                                'children' => array(
                                        array( 'name' => 'Bữa sáng', 'slug' => 'bua-sang' ),
                                        array( 'name' => 'Bữa trưa', 'slug' => 'bua-trua' ),
                                        array( 'name' => 'Bữa tối', 'slug' => 'bua-toi' ),
                                        array( 'name' => 'Ăn vặt lành mạnh', 'slug' => 'an-vat-lanh-manh' ),
                                        array( 'name' => 'Meal prep', 'slug' => 'meal-prep' ),
                                ),
                        ),
                        array(
                                'name'     => 'Kết hợp thực phẩm',
                                'slug'     => 'ket-hop-thuc-pham',
                                'children' => array(
                                        array( 'name' => 'Nên kết hợp', 'slug' => 'nen-ket-hop' ),
                                        array( 'name' => 'Không nên kết hợp', 'slug' => 'khong-nen-ket-hop' ),
                                ),
                        ),
                        array(
                                'name'     => 'Theo nhu cầu',
                                'slug'     => 'theo-nhu-cau',
                                'children' => array(
                                        array( 'name' => 'Giảm cân', 'slug' => 'giam-can' ),
                                        array( 'name' => 'Tiểu đường', 'slug' => 'tieu-duong' ),
                                        array( 'name' => 'Dạ dày', 'slug' => 'da-day' ),
                                        array( 'name' => 'Mỡ máu – tim mạch', 'slug' => 'mo-mau-tim-mach' ),
                                        array( 'name' => 'Gan', 'slug' => 'gan' ),
                                        array( 'name' => 'Gout', 'slug' => 'gout' ),
                                ),
                        ),
                        array(
                                'name'     => 'Review & Gợi ý mua',
                                'slug'     => 'review-goi-y',
                                'children' => array(
                                        array( 'name' => 'Top list', 'slug' => 'top-list' ),
                                        array( 'name' => 'Review chi tiết', 'slug' => 'review-chi-tiet' ),
                                ),
                        ),
                );
        }

	/**
	 * Create a category branch.
	 *
	 * @param array $category Category data.
	 *
	 * @return array
	 */
        private function create_category_branch( $category, $parent_id = 0 ) {
                $log = array();
                $term_id = 0;

		$existing = term_exists( $category['slug'], 'category' );

		if ( $existing && ! is_wp_error( $existing ) ) {
			$term_id                                = (int) $existing['term_id'];
			$this->category_ids[ $category['slug'] ] = $term_id;
			$log[]                                  = sprintf( __( 'Category "%1$s" already exists (ID %2$d).', 'food-herb-blog-setup' ), $category['name'], $term_id );
		} else {
			$result = wp_insert_term(
				$category['name'],
				'category',
				array(
					'slug'   => $category['slug'],
					'parent' => $parent_id,
				)
			);

                        if ( ! is_wp_error( $result ) ) {
                                $term_id                                = (int) $result['term_id'];
                                $this->category_ids[ $category['slug'] ] = $term_id;
                                $log[]                                  = sprintf( __( 'Created category "%1$s" (ID %2$d).', 'food-herb-blog-setup' ), $category['name'], $term_id );
                        } else {
                                $log[] = sprintf( __( 'Failed to create category "%1$s": %2$s', 'food-herb-blog-setup' ), $category['name'], $result->get_error_message() );
                                return $log;
                        }
                }

                if ( ! empty( $category['children'] ) && ! empty( $term_id ) ) {
                        foreach ( $category['children'] as $child ) {
                                $log = array_merge( $log, $this->create_category_branch( $child, $term_id ) );
                        }
                }

                return $log;
        }

        /**
         * Get status data for all predefined categories.
         *
         * @return array
         */
        public function get_category_status() {
                $statuses = array();

                foreach ( $this->get_category_structures() as $category ) {
                        $statuses[] = $this->get_category_status_branch( $category );
                }

                return $statuses;
        }

        /**
         * Get status for a single category branch.
         *
         * @param array $category Category data.
         *
         * @return array
         */
        private function get_category_status_branch( $category ) {
                $term     = get_category_by_slug( $category['slug'] );
                $children = array();

                if ( ! empty( $category['children'] ) ) {
                        foreach ( $category['children'] as $child ) {
                                $children[] = $this->get_category_status_branch( $child );
                        }
                }

                return array(
                        'name'      => $category['name'],
                        'slug'      => $category['slug'],
                        'exists'    => ( $term && ! is_wp_error( $term ) ),
                        'term_id'   => ( $term && ! is_wp_error( $term ) ) ? (int) $term->term_id : 0,
                        'edit_link' => ( $term && ! is_wp_error( $term ) ) ? get_edit_term_link( $term->term_id, 'category' ) : '',
                        'children'  => $children,
                );
        }

	/**
	 * Create default tags.
	 *
	 * @return array
	 */
	private function create_tags() {
		$tags = array(
			'low-gi',
			'it-duong',
			'giau-chat-xo',
			'protein-cao',
			'10-phut',
			'dan-van-phong',
			'ngan-sach-thap',
			'nguoi-dang-dung-thuoc',
			'me-bau',
		);

		$log = array();

		foreach ( $tags as $tag ) {
			$existing = term_exists( $tag, 'post_tag' );

			if ( $existing && ! is_wp_error( $existing ) ) {
				$log[] = sprintf( __( 'Tag "%1$s" already exists (ID %2$d).', 'food-herb-blog-setup' ), $tag, (int) $existing['term_id'] );
				continue;
			}

			$result = wp_insert_term( $tag, 'post_tag', array( 'slug' => $tag ) );

			if ( ! is_wp_error( $result ) ) {
				$log[] = sprintf( __( 'Created tag "%1$s" (ID %2$d).', 'food-herb-blog-setup' ), $tag, (int) $result['term_id'] );
			} else {
				$log[] = sprintf( __( 'Failed to create tag "%1$s": %2$s', 'food-herb-blog-setup' ), $tag, $result->get_error_message() );
			}
		}

		return $log;
	}

	/**
	 * Create or update the main navigation menu.
	 *
	 * @return array
	 */
        private function create_menu() {
                $log = array();
                $menu_name = 'Main Menu';
		$menu      = wp_get_nav_menu_object( $menu_name );

		if ( ! $menu ) {
			$menu_id = wp_create_nav_menu( $menu_name );
			$log[]   = sprintf( __( 'Created menu "%s".', 'food-herb-blog-setup' ), $menu_name );
		} else {
			$menu_id = (int) $menu->term_id;
			$log[]   = sprintf( __( 'Menu "%s" already exists.', 'food-herb-blog-setup' ), $menu_name );
		}

		$menu_items = wp_get_nav_menu_items( $menu_id );

		$structure = array(
			array(
				'title' => __( 'Trang chủ', 'food-herb-blog-setup' ),
				'type'  => 'page',
				'slug'  => 'home',
			),
			array(
				'title'    => __( 'Theo nhu cầu', 'food-herb-blog-setup' ),
				'type'     => 'custom',
				'url'      => '#',
				'children' => array(
					array( 'title' => __( 'Giảm cân', 'food-herb-blog-setup' ), 'type' => 'category', 'slug' => 'giam-can' ),
					array( 'title' => __( 'Tiểu đường', 'food-herb-blog-setup' ), 'type' => 'category', 'slug' => 'tieu-duong' ),
					array( 'title' => __( 'Dạ dày', 'food-herb-blog-setup' ), 'type' => 'category', 'slug' => 'da-day' ),
					array( 'title' => __( 'Mỡ máu – tim mạch', 'food-herb-blog-setup' ), 'type' => 'category', 'slug' => 'mo-mau-tim-mach' ),
					array( 'title' => __( 'Gan', 'food-herb-blog-setup' ), 'type' => 'category', 'slug' => 'gan' ),
					array( 'title' => __( 'Gout', 'food-herb-blog-setup' ), 'type' => 'category', 'slug' => 'gout' ),
				),
			),
			array(
				'title'    => __( 'Chủ đề', 'food-herb-blog-setup' ),
				'type'     => 'custom',
				'url'      => '#',
				'children' => array(
					array( 'title' => __( 'Thực phẩm', 'food-herb-blog-setup' ), 'type' => 'category', 'slug' => 'thuc-pham' ),
					array( 'title' => __( 'Dược liệu – thảo mộc', 'food-herb-blog-setup' ), 'type' => 'category', 'slug' => 'duoc-lieu-thao-moc' ),
					array( 'title' => __( 'Trà & thức uống thảo mộc', 'food-herb-blog-setup' ), 'type' => 'category', 'slug' => 'tra-thuc-uong-thao-moc' ),
					array( 'title' => __( 'Công thức', 'food-herb-blog-setup' ), 'type' => 'category', 'slug' => 'cong-thuc' ),
					array( 'title' => __( 'Kết hợp thực phẩm', 'food-herb-blog-setup' ), 'type' => 'category', 'slug' => 'ket-hop-thuc-pham' ),
					array( 'title' => __( 'Review & Gợi ý mua', 'food-herb-blog-setup' ), 'type' => 'category', 'slug' => 'review-goi-y' ),
				),
			),
			array(
				'title' => __( 'Tra nhanh', 'food-herb-blog-setup' ),
				'type'  => 'page',
				'slug'  => 'tra-nhanh',
			),
			array(
				'title' => __( 'Bắt đầu từ đây', 'food-herb-blog-setup' ),
				'type'  => 'page',
				'slug'  => 'bat-dau-tu-day',
			),
			array(
				'title' => __( 'Liên hệ', 'food-herb-blog-setup' ),
				'type'  => 'page',
				'slug'  => 'lien-he',
			),
		);

		foreach ( $structure as $item ) {
			$this->add_menu_item( $menu_id, $menu_items, $item );
		}

		$locations = get_nav_menu_locations();

		if ( isset( $locations['primary'] ) && (int) $locations['primary'] !== (int) $menu_id ) {
			$locations['primary'] = $menu_id;
			set_theme_mod( 'nav_menu_locations', $locations );
			$log[] = __( 'Assigned "Main Menu" to the primary location.', 'food-herb-blog-setup' );
		} elseif ( isset( $locations['primary'] ) ) {
			$log[] = __( 'Primary menu location already uses "Main Menu".', 'food-herb-blog-setup' );
		} else {
			$log[] = __( 'Primary menu location not found in current theme; menu created without assignment.', 'food-herb-blog-setup' );
		}

                return $log;
        }

        /**
         * Get overview data for the main menu.
         *
         * @return array
         */
        public function get_menu_overview() {
                $menu_name = 'Main Menu';
                $menu      = wp_get_nav_menu_object( $menu_name );
                $menu_id   = $menu ? (int) $menu->term_id : 0;

                $locations          = get_nav_menu_locations();
                $primary_location   = isset( $locations['primary'] ) ? (int) $locations['primary'] : 0;
                $is_primary_assigned = $menu_id && $primary_location && (int) $primary_location === (int) $menu_id;

                $items     = $menu_id ? wp_get_nav_menu_items( $menu_id ) : array();
                $top_level = array();

                if ( ! empty( $items ) ) {
                        foreach ( $items as $item ) {
                                if ( 0 === (int) $item->menu_item_parent ) {
                                        $top_level[] = wp_strip_all_tags( $item->title );
                                }
                        }
                }

                return array(
                        'name'                        => $menu_name,
                        'menu_id'                     => $menu_id,
                        'exists'                      => (bool) $menu,
                        'edit_url'                    => $menu_id ? admin_url( 'nav-menus.php?action=edit&menu=' . $menu_id ) : admin_url( 'nav-menus.php' ),
                        'is_primary_assigned'         => $is_primary_assigned,
                        'primary_location_available'  => array_key_exists( 'primary', $locations ),
                        'top_level_items'             => $top_level,
                );
        }

	/**
	 * Add a single menu item (recursively adds children).
	 *
	 * @param int   $menu_id Menu ID.
	 * @param array $existing_items Existing menu items.
	 * @param array $item Menu item data.
	 * @param int   $parent Parent item ID.
	 */
	private function add_menu_item( $menu_id, &$existing_items, $item, $parent = 0 ) {
		$existing_id = $this->find_existing_menu_item( $existing_items, $item, $parent );

		if ( $existing_id ) {
			$parent_id = $existing_id;
		} else {
			$args = array(
				'menu-item-title'     => wp_strip_all_tags( $item['title'] ),
				'menu-item-status'    => 'publish',
				'menu-item-parent-id' => $parent,
			);

			if ( 'page' === $item['type'] && isset( $this->page_ids[ $item['slug'] ] ) ) {
				$args['menu-item-object']    = 'page';
				$args['menu-item-object-id'] = $this->page_ids[ $item['slug'] ];
				$args['menu-item-type']      = 'post_type';
			} elseif ( 'category' === $item['type'] && isset( $this->category_ids[ $item['slug'] ] ) ) {
				$args['menu-item-object']    = 'category';
				$args['menu-item-object-id'] = $this->category_ids[ $item['slug'] ];
				$args['menu-item-type']      = 'taxonomy';
			} else {
				$args['menu-item-type'] = 'custom';
				$args['menu-item-url']  = isset( $item['url'] ) ? esc_url_raw( $item['url'] ) : '#';
			}

			$parent_id = wp_update_nav_menu_item( $menu_id, 0, $args );

			if ( ! is_wp_error( $parent_id ) ) {
				$existing_items[] = (object) array(
					'ID'                => $parent_id,
					'title'             => $item['title'],
					'menu_item_parent'  => $parent,
					'object_id'         => isset( $args['menu-item-object-id'] ) ? (int) $args['menu-item-object-id'] : 0,
					'object'            => isset( $args['menu-item-object'] ) ? $args['menu-item-object'] : 'custom',
					'type'              => $args['menu-item-type'],
					'url'               => isset( $args['menu-item-url'] ) ? $args['menu-item-url'] : '',
				);
			}
		}

		if ( ! empty( $item['children'] ) && $parent_id ) {
			foreach ( $item['children'] as $child ) {
				$this->add_menu_item( $menu_id, $existing_items, $child, $parent_id );
			}
		}
	}

	/**
	 * Find an existing menu item matching the candidate.
	 *
	 * @param array $existing_items Menu items.
	 * @param array $candidate Candidate item.
	 * @param int   $parent Parent ID.
	 *
	 * @return int
	 */
	private function find_existing_menu_item( $existing_items, $candidate, $parent ) {
		foreach ( (array) $existing_items as $item ) {
			if ( (int) $item->menu_item_parent !== (int) $parent ) {
				continue;
			}

			$title_matches = wp_strip_all_tags( $item->title ) === wp_strip_all_tags( $candidate['title'] );

			if ( 'page' === $candidate['type'] && isset( $this->page_ids[ $candidate['slug'] ] ) ) {
				if ( $title_matches && (int) $item->object_id === (int) $this->page_ids[ $candidate['slug'] ] ) {
					return (int) $item->ID;
				}
			} elseif ( 'category' === $candidate['type'] && isset( $this->category_ids[ $candidate['slug'] ] ) ) {
				if ( $title_matches && (int) $item->object_id === (int) $this->category_ids[ $candidate['slug'] ] ) {
					return (int) $item->ID;
				}
			} elseif ( 'custom' === $candidate['type'] ) {
				$target_url = isset( $candidate['url'] ) ? $candidate['url'] : '#';
				if ( $title_matches && $item->type === 'custom' && $item->url === $target_url ) {
					return (int) $item->ID;
				}
			}
		}

		return 0;
	}

	/**
	 * Set static front page and posts page.
	 *
	 * @return array
	 */
	private function set_reading_settings() {
		$log = array();

		$front_page = isset( $this->page_ids['home'] ) ? $this->page_ids['home'] : 0;
		$posts_page = isset( $this->page_ids['blog'] ) ? $this->page_ids['blog'] : 0;

		if ( $front_page && get_option( 'page_on_front' ) !== $front_page ) {
			update_option( 'page_on_front', $front_page );
			$log[] = __( 'Assigned "Trang chủ" as the static front page.', 'food-herb-blog-setup' );
		}

		if ( $posts_page && get_option( 'page_for_posts' ) !== $posts_page ) {
			update_option( 'page_for_posts', $posts_page );
			$log[] = __( 'Assigned "Blog" as the posts page.', 'food-herb-blog-setup' );
		}

		if ( 'page' !== get_option( 'show_on_front' ) ) {
			update_option( 'show_on_front', 'page' );
			$log[] = __( 'Updated Reading setting to use a static page.', 'food-herb-blog-setup' );
		}

		return $log;
	}

	/**
	 * Set permalink structure.
	 *
	 * @return array
	 */
	private function set_permalinks() {
		$log                 = array();
		$desired_structure   = '/%postname%/';
		$current_structure   = get_option( 'permalink_structure' );

		if ( $desired_structure !== $current_structure ) {
			update_option( 'permalink_structure', $desired_structure );
			flush_rewrite_rules();
			$log[] = __( 'Permalink structure updated to /%postname%/.', 'food-herb-blog-setup' );
		} else {
			$log[] = __( 'Permalink structure already set to /%postname%/.', 'food-herb-blog-setup' );
		}

		return $log;
	}

	/**
	 * Content for the homepage placeholder.
	 *
	 * @return string
	 */
	private function get_home_content() {
		return <<<HTML
<!-- wp:group {"layout":{"type":"constrained"}} -->
<div class="wp-block-group"><!-- wp:heading {"textAlign":"center"} -->
<h2 class="wp-block-heading has-text-align-center">Trang chủ – Tổng quan</h2>
<!-- /wp:heading -->

<!-- wp:paragraph {"align":"center"} -->
<p class="has-text-align-center">Hero + giới thiệu ngắn về blog thực phẩm, dược liệu, trà thảo mộc và công thức.</p>
<!-- /wp:paragraph --></div>
<!-- /wp:group -->

<!-- wp:separator {"className":"is-style-wide"} -->
<hr class="wp-block-separator has-alpha-channel-opacity is-style-wide" />
<!-- /wp:separator -->

<!-- wp:heading -->
<h2 class="wp-block-heading">Theo nhu cầu</h2>
<!-- /wp:heading -->

<!-- wp:paragraph -->
<p>Tạo danh sách block hoặc pattern cho 6 nhu cầu sức khỏe để dẫn tới category tương ứng.</p>
<!-- /wp:paragraph -->

<!-- wp:heading -->
<h2 class="wp-block-heading">Tra nhanh</h2>
<!-- /wp:heading -->

<!-- wp:paragraph -->
<p>Khối tra cứu nhanh về tác dụng, kỵ khi kết hợp, và trà thảo mộc nổi bật.</p>
<!-- /wp:paragraph -->

<!-- wp:heading -->
<h2 class="wp-block-heading">Công thức nổi bật</h2>
<!-- /wp:heading -->

<!-- wp:paragraph -->
<p>Query Loop placeholder hiển thị công thức phổ biến.</p>
<!-- /wp:paragraph -->

<!-- wp:heading -->
<h2 class="wp-block-heading">Review &amp; Gợi ý mua</h2>
<!-- /wp:heading -->

<!-- wp:paragraph -->
<p>Query Loop placeholder cho bài review/affiliate.</p>
<!-- /wp:paragraph -->

<!-- wp:heading -->
<h2 class="wp-block-heading">Email opt-in</h2>
<!-- /wp:heading -->

<!-- wp:paragraph -->
<p>Form đăng ký nhận bài viết mới và mẹo sức khỏe.</p>
<!-- /wp:paragraph -->
HTML;
	}

	/**
	 * Content for the "Bắt đầu từ đây" page.
	 *
	 * @return string
	 */
	private function get_getting_started_content() {
		return <<<HTML
<!-- wp:group {"layout":{"type":"constrained"}} -->
<div class="wp-block-group"><!-- wp:heading -->
<h2 class="wp-block-heading">Bắt đầu từ đây</h2>
<!-- /wp:heading -->

<!-- wp:paragraph -->
<p>Giới thiệu cách sử dụng blog: chọn chủ đề, xem theo nhu cầu, và tìm công thức nhanh.</p>
<!-- /wp:paragraph -->

<!-- wp:columns -->
<div class="wp-block-columns"><!-- wp:column -->
<div class="wp-block-column"><!-- wp:heading {"level":3} -->
<h3 class="wp-block-heading">Chọn theo nhu cầu</h3>
<!-- /wp:heading -->

<!-- wp:list -->
<ul><li>Giảm cân, tiểu đường, dạ dày</li><li>Mỡ máu – tim mạch, gan, gout</li></ul>
<!-- /wp:list --></div>
<!-- /wp:column -->

<!-- wp:column -->
<div class="wp-block-column"><!-- wp:heading {"level":3} -->
<h3 class="wp-block-heading">Chọn theo chủ đề</h3>
<!-- /wp:heading -->

<!-- wp:list -->
<ul><li>Thực phẩm, dược liệu, trà thảo mộc</li><li>Công thức, kết hợp thực phẩm, review</li></ul>
<!-- /wp:list --></div>
<!-- /wp:column --></div>
<!-- /wp:columns --></div>
<!-- /wp:group -->
HTML;
	}

	/**
	 * Content for the knowledge library page.
	 *
	 * @return string
	 */
	private function get_knowledge_library_content() {
		return <<<HTML
<!-- wp:group {"layout":{"type":"constrained"}} -->
<div class="wp-block-group"><!-- wp:heading -->
<h2 class="wp-block-heading">Thư viện kiến thức</h2>
<!-- /wp:heading -->

<!-- wp:paragraph -->
<p>Danh mục liên kết tới các category chính của blog.</p>
<!-- /wp:paragraph -->

<!-- wp:list -->
<ul><li>Thực phẩm</li><li>Dược liệu – thảo mộc</li><li>Trà &amp; thức uống thảo mộc</li><li>Công thức</li><li>Kết hợp thực phẩm</li><li>Review &amp; Gợi ý mua</li></ul>
<!-- /wp:list --></div>
<!-- /wp:group -->
HTML;
	}

	/**
	 * Content for quick lookup page.
	 *
	 * @return string
	 */
	private function get_quick_lookup_content() {
		return <<<HTML
<!-- wp:group {"layout":{"type":"constrained"}} -->
<div class="wp-block-group"><!-- wp:heading -->
<h2 class="wp-block-heading">Tra nhanh</h2>
<!-- /wp:heading -->

<!-- wp:columns -->
<div class="wp-block-columns"><!-- wp:column -->
<div class="wp-block-column"><!-- wp:heading {"level":3} -->
<h3 class="wp-block-heading">Tác dụng của...</h3>
<!-- /wp:heading -->

<!-- wp:paragraph -->
<p>Liệt kê nhanh lợi ích nổi bật của dược liệu, thực phẩm.</p>
<!-- /wp:paragraph --></div>
<!-- /wp:column -->

<!-- wp:column -->
<div class="wp-block-column"><!-- wp:heading {"level":3} -->
<h3 class="wp-block-heading">Kỵ khi kết hợp...</h3>
<!-- /wp:heading -->

<!-- wp:paragraph -->
<p>Lưu ý kết hợp thực phẩm nên tránh, chống chỉ định.</p>
<!-- /wp:paragraph --></div>
<!-- /wp:column -->

<!-- wp:column -->
<div class="wp-block-column"><!-- wp:heading {"level":3} -->
<h3 class="wp-block-heading">Trà thảo mộc...</h3>
<!-- /wp:heading -->

<!-- wp:paragraph -->
<p>Các loại trà hỗ trợ tiêu hoá, ngủ ngon, thanh nhiệt, giảm cân.</p>
<!-- /wp:paragraph --></div>
<!-- /wp:column --></div>
<!-- /wp:columns -->

<!-- wp:paragraph -->
<p>Gợi ý bài nổi bật (placeholder) để người dùng tìm nhanh.</p>
<!-- /wp:paragraph --></div>
<!-- /wp:group -->
HTML;
	}

	/**
	 * Content for review page.
	 *
	 * @return string
	 */
	private function get_review_content() {
		return <<<HTML
<!-- wp:group {"layout":{"type":"constrained"}} -->
<div class="wp-block-group"><!-- wp:heading -->
<h2 class="wp-block-heading">Review &amp; Gợi ý mua</h2>
<!-- /wp:heading -->

<!-- wp:heading {"level":3} -->
<h3 class="wp-block-heading">Top list</h3>
<!-- /wp:heading -->

<!-- wp:paragraph -->
<p>Danh sách sản phẩm khuyến nghị, liệt kê lý do nên mua.</p>
<!-- /wp:paragraph -->

<!-- wp:heading {"level":3} -->
<h3 class="wp-block-heading">Review chi tiết</h3>
<!-- /wp:heading -->

<!-- wp:paragraph -->
<p>Placeholder cho bài review chuyên sâu từng sản phẩm.</p>
<!-- /wp:paragraph -->

<!-- wp:group {"style":{"border":{"width":"1px"},"spacing":{"padding":{"top":"16px","bottom":"16px","left":"16px","right":"16px"}}},"layout":{"type":"constrained"}} -->
<div class="wp-block-group" style="border-width:1px;padding-top:16px;padding-right:16px;padding-bottom:16px;padding-left:16px"><!-- wp:heading {"level":4} -->
<h4 class="wp-block-heading">Minh bạch affiliate</h4>
<!-- /wp:heading -->

<!-- wp:paragraph -->
<p>Các liên kết có thể là affiliate, blog cam kết đánh giá trung thực và khách quan.</p>
<!-- /wp:paragraph --></div>
<!-- /wp:group --></div>
<!-- /wp:group -->
HTML;
	}

	/**
	 * Content for disclaimer page.
	 *
	 * @return string
	 */
	private function get_disclaimer_content() {
		return <<<HTML
<!-- wp:group {"layout":{"type":"constrained"}} -->
<div class="wp-block-group"><!-- wp:heading -->
<h2 class="wp-block-heading">Disclaimer sức khỏe</h2>
<!-- /wp:heading -->

<!-- wp:paragraph -->
<p>Thông tin trên blog chỉ mang tính tham khảo, không thay thế tư vấn y khoa cá nhân. Luôn tham khảo chuyên gia trước khi thay đổi chế độ ăn hoặc dùng sản phẩm.</p>
<!-- /wp:paragraph --></div>
<!-- /wp:group -->
HTML;
	}

	/**
	 * Content for affiliate policy page.
	 *
	 * @return string
	 */
	private function get_affiliate_policy_content() {
		return <<<HTML
<!-- wp:group {"layout":{"type":"constrained"}} -->
<div class="wp-block-group"><!-- wp:heading -->
<h2 class="wp-block-heading">Chính sách affiliate / Minh bạch</h2>
<!-- /wp:heading -->

<!-- wp:paragraph -->
<p>Một số liên kết trên blog là affiliate. Chúng tôi chỉ đề xuất sản phẩm có giá trị, không ảnh hưởng đến đánh giá. Bạn không mất thêm chi phí khi mua qua liên kết.</p>
<!-- /wp:paragraph --></div>
<!-- /wp:group -->
HTML;
	}

	/**
	 * Content for contact page.
	 *
	 * @return string
	 */
	private function get_contact_content() {
		return <<<HTML
<!-- wp:group {"layout":{"type":"constrained"}} -->
<div class="wp-block-group"><!-- wp:heading -->
<h2 class="wp-block-heading">Liên hệ</h2>
<!-- /wp:heading -->

<!-- wp:paragraph -->
<p>Thêm form liên hệ hoặc thông tin email của bạn tại đây.</p>
<!-- /wp:paragraph --></div>
<!-- /wp:group -->
HTML;
	}

	/**
	 * Content for the blog page placeholder.
	 *
	 * @return string
	 */
	private function get_blog_placeholder() {
		return <<<HTML
<!-- wp:paragraph -->
<p>Các bài viết mới nhất sẽ hiển thị ở đây.</p>
<!-- /wp:paragraph -->
HTML;
	}
}
