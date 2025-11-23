( function( $ ) {
	wp.customize( 'first_theme_home_title', function( value ) {
		value.bind( function( newVal ) {
			$( '.hero__title' ).text( newVal );
		} );
	} );
} )( jQuery );
